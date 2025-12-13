# Prerequisites for running the scripts

## Required Tools

* Java 8
* Java 11
* Python 3
* Git ≥ 1.9
* Subversion (svn) ≥ 1.8
* Perl ≥ 5.12
* cpanm (Perl module installer)
  To install `cpanm`:

  ```sh
  curl -L https://cpanmin.us | perl - App::cpanminus
  ```

### Python Dependencies

Before running any experiment scripts, ensure the following Python packages are installed:

* `pandas`
* `matplotlib`
* `seaborn`

Install these packages using your preferred Python package manager.

#### With pip

```sh
pip install pandas matplotlib seaborn
```

#### With uv

```sh
uv pip install pandas matplotlib seaborn
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
export PATH="$PATH":"$PATH2DEFECTS4J/framework/bin"
```

where "PATH2DEFECTS4J" points to the directory which Defects4J is in; it most
likely will look like "currentdirectory/build/defects4j".

### Java Versions Setup

Set the following environment variables in your shell configuration file
(e.g., `.bashrc`, `.zshrc`, or `.bash_profile`):

```sh
export JAVA8_HOME=/path/to/your/java8
export JAVA11_HOME=/path/to/your/java11
```

This is needed because different scripts require different Java versions:

* **Defect scripts** (via [Defects4J](https://github.com/rjust/defects4j))
  require **Java 11**.
* **Mutation scripts** (via [Major](https://github.com/rjust/major))
  require **Java 8**.
