# Bake - The CakeML Build Tool

Bake is a build tool for CakeML projects, designed to help manage dependencies and automate the process of building CakeML codebases. It is especially useful for projects that use [EasyBakeCakeML](https://github.com/Durbatuluk1701/EasyBakeCakeML) or generate `.cml` files from other sources.

## Motivation

CakeML lacks a native module or import system, making it difficult to manage large projects with multiple files. Bake introduces a simple dependency annotation system using comments in `.cml` files, allowing you to specify dependencies and automate the process of merging and building your project.

## Dependency Annotation

Each `.cml` file that depends on other files should have its **first** line as:

```sml
(* deps: <dependencies>+ *)
```

- List dependencies by their base name (no `.cml` extension).
- Nested dependencies can be written as `Y/X` or `Y.X` (both are equivalent).
- Dependencies starting with `@` are resolved from the project root; others are resolved relative to the current file.
- Dependencies starting with `$` are resolved from the stubs directory (provided via `--stubs <dir>` or the `CAKEML_STUBS` environment variable). This is useful for substituting stub or platform-specific files, such as for testing or platform abstraction.

**Examples:**

- In `Y/Z.cml`, `X` means `Y/X.cml` (relative), while `@X` means `X.cml` at the project root.
- `$Test_Stubs` in any file will resolve to `Test_Stubs.cml` in the stubs directory.

## Modes of Operation

Bake supports three main modes, controlled by the `--mode` argument:

- `--mode print`: Resolves and prints the full dependency list for a given `.cml` file. Output can be redirected to a file with `--out <file>`.
- `--mode merge`: Resolves dependencies and merges all required `.cml` files into a single monolithic file (specified by `--out <file>`).
- `--mode build`: Merges dependencies, compiles the result with the CakeML compiler (`cake`), and then compiles the output to a native executable using `gcc`.

## Usage

```sh
bake <main.cml> [--mode print|merge|build] [--out <file>] [--stubs <dir>]
```

- `<main.cml>`: The entry point CakeML file.
- `--mode`: Selects the operation mode (`print`, `merge`, or `build`). Default is `build`.
- `--out <file>`: Output file for the merged CakeML code (required for `merge` and `build`).
- `--stubs <dir>`: Optional directory for stub file substitution.

## Quirks and Notes

- The tool assumes your C compiler is `gcc`, the basis file is `basis_ffi.c`, and uses the flags `-O2 -lm`.
- There is currently no cleaning functionality.
- The `--out` argument specifies the output monolithic CakeML file; in `build` mode, the executable will be named after the output file (without the `.cml` extension).
- Stub file substitution is supported for files ending in `_Stubs.cml` or `_Axioms.cml` via the `--stubs` option or the `CAKEML_STUBS` environment variable.
- Logging can be enabled by setting the `DEBUG` environment variable.

## Example

To print dependencies:

```sh
bake my_main.cml --mode print
```

To merge into a single file:

```sh
bake my_main.cml --mode merge --out merged.cml
```

To build an executable:

```sh
bake my_main.cml --mode build --out merged.cml
```

## License

See `LICENSE` for details.
