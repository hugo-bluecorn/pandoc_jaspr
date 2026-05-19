# Effective Dart: Style

> Source: https://dart.dev/effective-dart/style
> Fetched: 2026-05-19
>
> Canonical Dart style guide. Section headings (Identifiers, Ordering,
> Formatting) and rule callouts (DO / DON'T / PREFER / AVOID / CONSIDER)
> are preserved.

A guide to consistent naming, ordering, and formatting for readable Dart code across the ecosystem.

## Identifiers

Dart uses three identifier naming conventions:

- `UpperCamelCase`: Capitalizes the first letter of each word, including the first
- `lowerCamelCase`: Capitalizes each word except the first, which is always lowercase
- `lowercase_with_underscores`: Uses only lowercase letters with underscores separating words

### DO name types using `UpperCamelCase`

Classes, enum types, typedefs, and type parameters should follow this pattern.

```dart
class SliderMenu {
  ...
}

class HttpRequest {
  ...
}

typedef Predicate<T> = bool Function(T value);
```

This includes annotation classes:

```dart
class Foo {
  const Foo([Object? arg]);
}

@Foo(anArg)
class A { ... }

@Foo()
class B { ... }
```

For annotation classes with no-argument constructors, create a `lowerCamelCase` constant:

```dart
const foo = Foo();

@foo
class C { ... }
```

### DO name extensions using `UpperCamelCase`

Extensions should capitalize the first letter of each word with no separators.

```dart
extension MyFancyList<T> on List<T> {
  ...
}

extension SmartIterable<T> on Iterable<T> {
  ...
}
```

### DO name packages, directories, and source files using `lowercase_with_underscores`

This accommodates case-insensitive file systems and maintains readability.

**Good:**
```
my_package
└─ lib
   └─ file_system.dart
   └─ slider_menu.dart
```

**Bad:**
```
mypackage
└─ lib
   └─ file-system.dart
   └─ SliderMenu.dart
```

### DO name import prefixes using `lowercase_with_underscores`

```dart
import 'dart:math' as math;
import 'package:angular_components/angular_components.dart' as angular_components;
import 'package:js/js.dart' as js;
```

Not:
```dart
import 'dart:math' as Math;
import 'package:angular_components/angular_components.dart' as angularComponents;
import 'package:js/js.dart' as JS;
```

### DO name other identifiers using `lowerCamelCase`

Class members, top-level definitions, variables, parameters, and named parameters should follow this pattern.

```dart
var count = 3;

HttpRequest httpRequest;

void align(bool clearItems) {
  // ...
}
```

### PREFER using `lowerCamelCase` for constant names

In new code, constants including enum values should use `lowerCamelCase`.

```dart
const pi = 3.14;
const defaultTimeout = 1000;
final urlScheme = RegExp('^([a-z]+):');

class Dice {
  static final numberGenerator = Random();
}
```

Not:
```dart
const PI = 3.14;
const DefaultTimeout = 1000;
final URL_SCHEME = RegExp('^([a-z]+):');

class Dice {
  static final NUMBER_GENERATOR = Random();
}
```

You may use `SCREAMING_CAPS` for consistency when adding to existing files that use it, or when generating code parallel to Java (such as protobuf enums).

### DO capitalize acronyms and abbreviations longer than two letters like words

Capitalized acronyms are hard to read; multiple adjacent acronyms create ambiguity. Treat them as regular words unless they're two-letter abbreviations that are capitalized in English.

**Good:**
```dart
Http      // hypertext transfer protocol
Nasa      // national aeronautics and space administration
Uri       // uniform resource identifier
Esq       // esquire

ID        // identifier (two letters, capitalized in English)
TV        // television
UI        // user interface

Mr        // mister (two letters, not capitalized in English)
St        // street
Rd        // road
```

**Bad:**
```dart
HTTP
NASA
URI
esq

Id
Tv
Ui

MR
ST
RD
```

When abbreviations start a `lowerCamelCase` identifier, use all lowercase:

```dart
var httpConnection = connect();
var tvSet = Television();
var mrRogers = 'hello, neighbor';
```

### PREFER using wildcards for unused callback parameters

For anonymous local functions where a parameter is required by the type signature but unused, use `_` to declare a non-binding wildcard variable.

```dart
futureOfVoid.then((_) {
  print('Operation complete.');
});
```

Multiple unused parameters can each be named `_`:

```dart
.onError((_, _) {
  print('Operation failed.');
});
```

This guideline applies only to anonymous local functions. Top-level functions and methods should have named parameters so readers understand what each represents, even if unused.

*Note:* Wildcard variables require language version 3.7 or later. For earlier versions, use additional underscores (`__`, `___`) and enable the `no_wildcard_variable_uses` lint.

### DON'T use a leading underscore for identifiers that aren't private

Leading underscores mark members and top-level declarations as private. Don't use them for local variables, parameters, local functions, or library prefixes, as this sends a confusing signal to readers.

### DON'T use prefix letters

There is no need for Hungarian notation or similar schemes. Dart's compiler provides type, scope, and mutability information.

**Good:**
```dart
defaultTimeout
```

**Bad:**
```dart
kDefaultTimeout
```

### DON'T explicitly name libraries

The `library` directive with an explicit name is a legacy feature. Dart generates a unique tag based on path and filename; naming libraries overrides this, making it harder for tools to locate the library file.

**Bad:**
```dart
library my_library;
```

**Good:**
```dart
/// A really great test library.
@TestOn('browser')
library;
```

## Ordering

Maintain a prescribed order for directives with blank lines separating each section.

### DO place `dart:` imports before other imports

```dart
import 'dart:async';
import 'dart:collection';

import 'package:bar/bar.dart';
import 'package:foo/foo.dart';
```

### DO place `package:` imports before relative imports

```dart
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';

import 'util.dart';
```

### DO specify exports in a separate section after all imports

```dart
import 'src/error.dart';
import 'src/foo_bar.dart';

export 'src/error.dart';
```

Not:
```dart
import 'src/error.dart';
export 'src/error.dart';
import 'src/foo_bar.dart';
```

### DO sort sections alphabetically

```dart
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';

import 'foo.dart';
import 'foo/foo.dart';
```

Not:
```dart
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';

import 'foo/foo.dart';
import 'foo.dart';
```

## Formatting

Consistent whitespace ensures readers see code the same way the compiler does.

### DO format your code using `dart format`

The automated formatter handles whitespace rules. The official formatting standard is whatever `dart format` produces. Consult the formatter FAQ for insight into its style choices.

### CONSIDER changing your code to make it more formatter-friendly

If the formatter's output remains hard to read despite best efforts, reorganize your code. Shorten variable names, hoist expressions into new variables, or simplify nested expressions. View formatting as a partnership where you iteratively refine code for readability.

### PREFER lines 80 characters or fewer

Readability studies show long lines tire the eye. Newspapers use multiple columns for this reason. If lines exceed 80 characters, your code is likely too verbose. Long `VeryLongCamelCaseClassNames` often sacrifice clarity—ask whether each word prevents collision or conveys critical information.

*Note:* `dart format` defaults to 80 characters (configurable), but does not split long string literals; you must do so manually.

**Exceptions:**
- URIs and file paths in comments or strings (imports/exports) may exceed 80 characters for searchability
- Multi-line strings can exceed 80 characters since newlines are significant

### DO use curly braces for all flow control statements

This avoids the dangling else problem.

```dart
if (isWeekDay) {
  print('Bike to work!');
} else {
  print('Go dancing or read a book!');
}
```

**Exception:** Single-line `if` statements without `else` may omit braces:

```dart
if (arg == null) return defaultValue;
```

If the body wraps to the next line, use braces:

```dart
if (overflowChars != other.overflowChars) {
  return overflowChars < other.overflowChars;
}
```

Not:
```dart
if (overflowChars != other.overflowChars)
  return overflowChars < other.overflowChars;
```

---

## Companion pages

This is the *Style* page of Effective Dart. The full guide has three more
companion pages the spike session may want to consult on dart.dev:

- **Documentation** — https://dart.dev/effective-dart/documentation
- **Usage** — https://dart.dev/effective-dart/usage (collections, strings, functions, variables, types, parameters, equality)
- **Design** — https://dart.dev/effective-dart/design (libraries, classes, constructors, members, types, parameters, equality)

If you need a rule that is not in this Style page, fetch the relevant
companion page rather than guessing.
