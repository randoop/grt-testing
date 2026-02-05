MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: \
    build/evosuite-1.2.0.jar \
    build/evosuite-standalone-runtime-1.2.0.jar \
    build/hamcrest-core-1.3.jar \
    build/jacoco.jar \
    build/junit-4.12.jar \
    build/major \
    build/major/bin/ant-replacecall \
    build/org.jacoco.agent-0.8.0-runtime.jar \
    build/randoop \
    build/randoop-all-4.3.4.jar \
    build/replacecall-4.3.4.jar \
    build/defects4j \
    results

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/org.jacoco.agent-0.8.0-runtime.jar:
	mkdir -p build
	cd build && wget -nv -O org.jacoco.agent-0.8.0-runtime.jar https://repo1.maven.org/maven2/org/jacoco/org.jacoco.agent/0.8.0/org.jacoco.agent-0.8.0-runtime.jar

build/randoop-all-4.3.4.jar:
	# mkdir -p build
	# cd build
	# wget -nv https://github.com/randoop/randoop/releases/download/v4.3.4/randoop-all-4.3.4.jar
	echo "See scripts/reproinstruction.txt to obtain randoop-all-4.3.4.jar"

build/major:
	mkdir -p build
	cd build && wget -nv https://mutation-testing.org/downloads/files/major-2.2.0_jre8.zip
	cd build && unzip -o major-2.2.0_jre8.zip

build/randoop:
	mkdir -p build
	cd build && git clone git@github.com:randoop/randoop.git

randoop-from-source:
	cd build/randoop && \
	git pull && \
	./gradlew shadowJar && \
	mv -f build/libs/randoop-all-4.3.4.jar ..

build/replacecall-4.3.4.jar:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/replacecall-4.3.4.jar" && \
	mv replacecall-4.3.4.jar build/

build/evosuite-1.2.0.jar:
	mkdir -p build
	cd build && wget https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-1.2.0.jar

build/evosuite-standalone-runtime-1.2.0.jar:
	mkdir -p build
	cd build && wget https://github.com/EvoSuite/evosuite/releases/download/v1.2.0/evosuite-standalone-runtime-1.2.0.jar

build/junit-4.12.jar:
	mkdir -p build
	cd build && wget https://repo1.maven.org/maven2/junit/junit/4.12/junit-4.12.jar

build/hamcrest-core-1.3.jar:
	mkdir -p build
	cp ../subject-programs/hamcrest-core-1.3.jar build/

build/major/bin/ant-replacecall:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/ant-replacecall" && \
	mv ant-replacecall build/major/bin/

build/defects4j:
	mkdir -p build
	cd build && git clone https://github.com/rjust/defects4j && cd defects4j && cpanm --installdeps . && ./init.sh

results:
	mkdir -p results

clean:
	rm -rf build results evosuite-tests evosuite-report target libs

experiment-clean:
	rm -rf build/bin/*
	rm -rf build/randoop-tests/*
	rm -rf build/evosuite-tests/*
	rm -rf build/evosuite-report/*
	rm -rf build/target/*
	rm -rf build/lib/*

src:
	get-all-subject-src.sh
