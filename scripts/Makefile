MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

all: build/jacoco.jar build/major build/major/bin/ant-replacecall build/randoop-all-4.3.3.jar build/randoop build/replacecall-4.3.3.jar results

build/jacoco.jar:
	mkdir -p build
	cd build && wget -nv -O jacoco-0.8.12.zip https://search.maven.org/remotecontent?filepath=org/jacoco/jacoco/0.8.12/jacoco-0.8.12.zip
	cd build && unzip -o jacoco-0.8.12.zip lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar && mv lib/jacocoagent.jar lib/jacocoant.jar lib/jacococli.jar . && rmdir lib

build/randoop-all-4.3.3.jar:
	# mkdir -p build
	# cd build
	# wget -nv https://github.com/randoop/randoop/releases/download/v4.3.3/randoop-all-4.3.3.jar
	echo "See scripts/reproinstruction.txt to obtain randoop-all-4.3.3.jar"

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
	mv -f build/libs/randoop-all-4.3.3.jar ..

build/replacecall-4.3.3.jar:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/replacecall-4.3.3.jar" && \
	mv replacecall-4.3.3.jar build/

build/major/bin/ant-replacecall:
	LATEST_RELEASE=$$(curl -s https://api.github.com/repos/randoop/grt-replacecall/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4) && \
	wget "https://github.com/randoop/grt-replacecall/releases/download/$${LATEST_RELEASE}/ant-replacecall" && \
	mv ant-replacecall build/major/bin/

results:
	mkdir -p results

clean:
	rm -rf build results

src:
	get-all-subject-src.sh
