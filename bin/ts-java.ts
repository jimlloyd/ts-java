/// <reference path='../node_modules/immutable/dist/immutable.d.ts'/>
/// <reference path='../typings/bluebird/bluebird.d.ts' />
/// <reference path='../typings/chalk/chalk.d.ts' />
/// <reference path='../typings/commander/commander.d.ts' />
/// <reference path="../typings/debug/debug.d.ts"/>
/// <reference path='../typings/glob/glob.d.ts' />
/// <reference path='../typings/handlebars/handlebars.d.ts' />
/// <reference path='../typings/lodash/lodash.d.ts' />
/// <reference path='../typings/mkdirp/mkdirp.d.ts' />
/// <reference path='../typings/node/node.d.ts' />
/// <reference path='../lib/jsonfile.d.ts' />

'use strict';

declare function require(name: string): any;
require('source-map-support').install();

import _ = require('lodash');
import BluePromise = require('bluebird');
import chalk = require('chalk');
import ClassesMap = require('../lib/classes-map');
import CodeWriter = require('../lib/code-writer');
import debug = require('debug');
import fs = require('fs');
import glob = require('glob');
import Immutable = require('immutable');
import java = require('java');
import jsonfile = require('jsonfile');
import mkdirp = require('mkdirp');
import path = require('path');
import program = require('commander');
import TsJavaOptions = require('../lib/TsJavaOptions');
import Work = require('../lib/work');

import ClassDefinition = ClassesMap.ClassDefinition;
import ClassDefinitionMap = ClassesMap.ClassDefinitionMap;

BluePromise.longStackTraces();
var writeFilePromise = BluePromise.promisify(fs.writeFile);
var readFilePromise = BluePromise.promisify(fs.readFile);
var mkdirpPromise = BluePromise.promisify(mkdirp);
var readJsonPromise = BluePromise.promisify(jsonfile.readFile);
var globPromise = BluePromise.promisify(glob);

var dlog = debug('ts-java:main');
var error = chalk.bold.red;

class Main {

  private options: TsJavaOptions;
  private classpath: Array<string>;

  constructor(options: TsJavaOptions) {
    this.options = options;
    this.classpath = [];
    if (this.options.granularity !== 'class') {
      this.options.granularity = 'package';
    }
    if (!this.options.outputPath) {
      this.options.outputPath = 'typings/java/java.d.ts';
    }
    if (!this.options.promisesPath) {
      // TODO: Provide more control over promises
      this.options.promisesPath = '../bluebird/bluebird.d.ts';
    }
  }

  run(): BluePromise<ClassesMap> {
    return this.initJava()
      .then(() => this.loadClasses())
      .then((classesMap: ClassesMap) => {
        return BluePromise.join(this.writeJsons(classesMap.getClasses()), this.writeInterpolatedFiles(classesMap))
          .then(() => dlog('run() completed.'))
          .then(() => classesMap);
      });
  }

  private writeInterpolatedFiles(classesMap: ClassesMap) : BluePromise<void> {
    return this.options.granularity === 'class' ? this.writeClassFiles(classesMap) : this.writePackageFiles(classesMap);
  }

  private writeJsons(classes: ClassDefinitionMap): BluePromise<void> {
    dlog('writeJsons() entered');
    return mkdirpPromise('o/json')
      .then(() => {
        return _.map(_.keys(classes), (className: string) => {
          var classMap = classes[className];
          return writeFilePromise('o/json/' + classMap.shortName + '.json', JSON.stringify(classMap, null, '  '));
        });
      })
      .then((promises: Promise<any[]>) => BluePromise.all(promises))
      .then(() => dlog('writeJsons() completed.'));
  }

  private writeClassFiles(classesMap: ClassesMap): BluePromise<void> {
    dlog('writeClassFiles() entered');
    return mkdirpPromise('o/lib')
      .then(() => {
        var templatesDirPath = path.resolve(__dirname, '..', 'ts-templates');
        var tsWriter = new CodeWriter(classesMap, templatesDirPath);
        var classes: ClassDefinitionMap = classesMap.getClasses();
        return _.map(_.keys(classes), (name: string) => tsWriter.writeLibraryClassFile(name, this.options.granularity));
      })
      .then((promises: Promise<any[]>) => BluePromise.all(promises))
      .then(() => dlog('writeClassFiles() completed.'));
  }

  private writePackageFiles(classesMap: ClassesMap): BluePromise<void> {
    dlog('writePackageFiles() entered');
    var templatesDirPath = path.resolve(__dirname, '..', 'ts-templates');
    var tsWriter = new CodeWriter(classesMap, templatesDirPath);
    var classes: ClassDefinitionMap = classesMap.getClasses();
    return mkdirpPromise(path.dirname(this.options.outputPath))
      .then(() => tsWriter.writePackageFile(this.options))
      .then(() => dlog('writePackageFiles() completed'));
  }

  private initJava(): BluePromise<void> {
    return BluePromise.all(_.map(this.options.classpath, (globExpr: string) => globPromise(globExpr)))
      .then((pathsArray: Array<Array<string>>) => _.flatten(pathsArray))
      .then((paths: Array<string>) => {
        _.forEach(paths, (path: string) => {
          dlog('Adding to classpath:', path);
          java.classpath.push(path);
          this.classpath.push(path);
        });
      });
  }

  private loadClasses(): BluePromise<ClassesMap> {
    var regExpWhiteList = _.map(this.options.whiteList, (str: string) => {
      // We used to have true regular expressions in source code.
      // Now we get the white list from the package.json, and convert the strings to RegExps.
      // But writing correct regular expressions in .json files is messy, due to json parser behavior.
      // See e.g. http://stackoverflow.com/questions/17597238/escaping-regex-to-get-valid-json
      // TODO: change the white list to be lists of packages and classes to be included.
      return new RegExp(str);
    });
    var classesMap = new ClassesMap(java, Immutable.Set(regExpWhiteList));
    return classesMap.initialize(this.options.seedClasses).then(() => classesMap);
  }
}

var helpText = [
'  All configuration options must be specified in a node.js package.json file, in a property tsjava.',
'  See the README.md file for more information.'
];

program.on('--help', () => {
  _.forEach(helpText, (line: string) => console.log(chalk.bold(line)));
});

program.parse(process.argv);

var packageJsonPath = './package.json';
readJsonPromise(packageJsonPath)
  .then((packageContents: any) => {

    if (!('tsjava' in packageContents)) {
      console.error(error('package.json does not contain a tsjava property'));
      program.help();
    }

    var main = new Main(packageContents.tsjava);
    return main.run()
      .then((classesMap: ClassesMap) => {
        console.log(classesMap.unhandledTypes);
      });
  })
  .catch((err: any) => {
    if ('cause' in err && err.cause.code === 'ENOENT' && err.cause.path === packageJsonPath) {
      console.error(error('Not found:', packageJsonPath));
      program.help();
    } else {
      console.error(error(err));
      if (err.stack) {
        console.error(err.stack);
      }
      process.exit(1);
    }
  })
  .done();

