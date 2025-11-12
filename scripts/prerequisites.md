# Prerequisites for running the scripts

## Java Versions Setup

Different scripts require different Java versions:

* **Defect scripts** (via [Defects4J](https://github.com/rjust/defects4j))
require **Java 11**
* **Mutation scripts** (via [Major](https://github.com/rjust/major))
require **Java 8**

To allow automatic switching between Java versions, set the following
environment variables in your shell configuration file
(e.g., `.bashrc`, `.zshrc`, or `.bash_profile`):

```sh
export JAVA8_HOME=/path/to/your/java8
export JAVA11_HOME=/path/to/your/java11
```

## Required Tools

* **Git** ≥ 1.9
* **Subversion (svn)** ≥ 1.8
* **Perl** ≥ 5.12
* **cpanm** (Perl module installer)
  To install `cpanm`:

  ```sh
  curl -L https://cpanmin.us | perl - App::cpanminus
  ```

## Obtaining Dependencies and Subject Programs

```sh
make -C scripts
make -C scripts randoop-from-source
cd scripts
./get-all-subject-src.sh
```

## Adding Defects4J to PATH

For defect detection scripts, add Defects4J's executables to your PATH in
the shell session where you run the scripts:

```sh
export PATH=$PATH:"path2defects4j"/framework/bin
```

> "path2defects4j" points to the directory which Defects4J is in; it most
likely will look like "currentdirectory/build/defects4j".
