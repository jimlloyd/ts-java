Feature: Primitive Type Coercions

As a developer learning how to use ts-java
I want to understand how Typescript maps primitive types between Java and Typescript
So I can understand how to primitive types and be aware of some limitations.

  Background:
    Given this boilerplate to intialize node-java:
    """
    /// <reference path='../../typings/power-assert/power-assert.d.ts' />

    import assert = require('power-assert');
    import java = require('../tsJavaModule');
    import util = require('util');

    import Java = java.Java;

    Java.ensureJvm().then(() => {
      var SomeClass = Java.importClass('com.redseal.featureset.SomeClass');
      var something: Java.SomeInterface = new SomeClass();
      {{{ scenario_snippet }}}
    });

    """

  Scenario: Java functions returning java.lang.String values return javascript strings.
    Given the above boilerplate with following scenario snippet:
    """
    var str: string = something.getString();
    assert.strictEqual(typeof str, 'string');
    assert.strictEqual(str, 'Just some class.');
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Java functions taking java.lang.String values accept javascript strings.
    Given the above boilerplate with following scenario snippet:
    """
    something.setString('foo');
    var str: string = something.getString();
    assert.strictEqual(typeof str, 'string');
    assert.strictEqual(str, 'foo');
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Java functions returning int values return javascript numbers.
    Given the above boilerplate with following scenario snippet:
    """
    var num: number = something.getInt();
    assert.strictEqual(typeof num, 'number');
    assert.strictEqual(num, 42);
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Java functions taking int values accept javascript numbers.
    Given the above boilerplate with following scenario snippet:
    """
    something.setInt(999);
    var num: number = something.getInt();
    assert.strictEqual(typeof num, 'number');
    assert.strictEqual(num, 999);
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Java functions returning long values return javascript objects containing both a number and a string.
    Given the above boilerplate with following scenario snippet:
    """
    var num: Java.longValue_t = something.getLong();
    assert.strictEqual(typeof num, 'object');
    assert.strictEqual(num.longValue, '9223372036854775807');
    assert.equal(num, 9223372036854776000);

    var formatted: string = util.inspect(num);
    assert.strictEqual(formatted, '{ [Number: 9223372036854776000] longValue: \'9223372036854775807\' }');
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Java functions returning boolean values return javascript booleans.
    Given the above boilerplate with following scenario snippet:
    """
    var val: boolean = something.getBoolean();
    assert.strictEqual(typeof val, 'boolean');
    assert.strictEqual(val, true);
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Java functions returning double values return javascript numbers.
    Given the above boilerplate with following scenario snippet:
    """
    var val: number = something.getDouble();
    assert.strictEqual(typeof val, 'number');
    assert.strictEqual(val, 3.141592653589793);
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Node-java always converts wrapped primitives to javascript primitives.
    Given the above boilerplate with following scenario snippet:
    """
    // Node-java always converts wrapper class instances for primitive types to
    // the corresponding primitive types, even via newInstance().
    var str: string = Java.newInstance('java.lang.String', 'hello');
    assert.strictEqual(typeof str, 'string');
    assert.strictEqual(str, 'hello');

    var num: number = Java.newInstance('java.lang.Integer', 42);
    assert.strictEqual(typeof num, 'number');
    assert.strictEqual(num, 42);

    Java.newInstanceA('java.lang.Double', 2.71828, (err: Error, num: number) => {
      assert.strictEqual(typeof num, 'number');
      assert.strictEqual(num, 2.71828);
    });
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: Object function results will be converted to primitive types when appropriate.
    Given the above boilerplate with following scenario snippet:
    """
    var result: Java.object_t;

    // Each of the getFooObject() methods below is declared to return a java.lang.Object,
    // but actually returns a specific type that can be coerced to a javascript type.
    // The special type Java.object_t makes it easy to work with such results.
    // Note that Java.object_t is declared as:
    // type object_t = java.lang.Object | string | number | longValue_t;

    result = something.getStringObject();
    assert.strictEqual(typeof result, 'string');
    assert.strictEqual(result, 'A String');

    result = something.getShortObject();
    assert.strictEqual(typeof result, 'number');
    assert.strictEqual(result, 42);

    result = something.getDoubleObject();
    assert.strictEqual(typeof result, 'number');
    assert.strictEqual(result, 3.141592653589793);

    result = something.getLongObject();
    assert.strictEqual(typeof result, 'object');
    assert.strictEqual((<Java.longValue_t>result).longValue, '9223372036854775807');
    assert.equal(result, 9223372036854776000);

    var formatted: string = util.inspect(result);
    assert.strictEqual(formatted, '{ [Number: 9223372036854776000] longValue: \'9223372036854775807\' }');
    """
    Then it compiles and lints cleanly
    And it runs and produces no output

  Scenario: newArray returns java object wrapper for the array.
    Given the above boilerplate with following scenario snippet:
    """
    var arr: Java.array_t<Java.java.lang.String> = Java.newArray('java.lang.String', ['hello', 'world']);
    console.log(typeof arr, arr);

    // TODO: ts-java needs generics to support something like the following:
    // var Arrays = java.importClass('java.util.Arrays');
    // var list: Java.java.util.List = Arrays.asList(arr);
    // console.log(list.toString());

    """
    Then it compiles and lints cleanly
    And it runs and produces output:
    """
    object {}

    """

