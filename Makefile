# ################################################################
# LZ4 - Makefile
# Copyright (C) Yann Collet 2011-2020
# All rights reserved.
#
# BSD license
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
#   list of conditions and the following disclaimer in the documentation and/or
#   other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# You can contact the author at :
#  - LZ4 source repository : https://github.com/lz4/lz4
#  - LZ4 forum froup : https://groups.google.com/forum/#!forum/lz4c
# ################################################################

LZ4DIR  = lib
PRGDIR  = programs
TESTDIR = tests
EXDIR   = examples
FUZZDIR = ossfuzz

include Makefile.inc


.PHONY: default
default: lib-release lz4-release

# silent mode by default; verbose can be triggered by V=1 or VERBOSE=1
$(V)$(VERBOSE).SILENT:

.PHONY: all
all: allmost examples manuals build_tests

.PHONY: allmost
allmost: lib lz4

.PHONY: lib lib-release liblz4.a
lib: liblz4.a
lib lib-release liblz4.a:
	$(MAKE) -C $(LZ4DIR) $@

.PHONY: lz4 lz4-release
lz4 : liblz4.a
lz4-release : lib-release
lz4 lz4-release :
	$(MAKE) -C $(PRGDIR) $@
	cp $(PRGDIR)/lz4$(EXT) .

.PHONY: examples
examples: liblz4.a
	$(MAKE) -C $(EXDIR) all

.PHONY: manuals
manuals:
	$(MAKE) -C contrib/gen_manual $@

.PHONY: build_tests
build_tests:
	$(MAKE) -C $(TESTDIR) all

.PHONY: clean
clean:
	$(MAKE) -C $(LZ4DIR) $@ > $(VOID)
	$(MAKE) -C $(PRGDIR) $@ > $(VOID)
	$(MAKE) -C $(TESTDIR) $@ > $(VOID)
	$(MAKE) -C $(EXDIR) $@ > $(VOID)
	$(MAKE) -C $(FUZZDIR) $@ > $(VOID)
	$(MAKE) -C contrib/gen_manual $@ > $(VOID)
	$(RM) lz4$(EXT)
	$(RM) -r $(CMAKE_BUILD_DIR)
	@echo Cleaning completed


#-----------------------------------------------------------------------------
# make install is validated only for Posix environments
#-----------------------------------------------------------------------------
ifeq ($(POSIX_ENV),Yes)
HOST_OS = POSIX

.PHONY: install uninstall
install uninstall:
	$(MAKE) -C $(LZ4DIR) $@
	$(MAKE) -C $(PRGDIR) $@

.PHONY: travis-install
travis-install:
	$(MAKE) -j1 install DESTDIR=~/install_test_dir

endif   # POSIX_ENV


CMAKE ?= cmake
CMAKE_BUILD_DIR ?= build/cmake/build
ifneq (,$(filter MSYS%,$(shell $(UNAME))))
HOST_OS = MSYS
CMAKE_PARAMS = -G"MSYS Makefiles"
endif

.PHONY: cmake
cmake:
	mkdir -p $(CMAKE_BUILD_DIR)
	cd $(CMAKE_BUILD_DIR); $(CMAKE) $(CMAKE_PARAMS) ..; $(CMAKE) --build .


#------------------------------------------------------------------------
# make tests validated only for MSYS and Posix environments
#------------------------------------------------------------------------
ifneq (,$(filter $(HOST_OS),MSYS POSIX))

.PHONY: list
list:
	$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

.PHONY: check
check:
	$(MAKE) -C $(TESTDIR) test-lz4-essentials

.PHONY: test
test:
	$(MAKE) -C $(TESTDIR) $@
	$(MAKE) -C $(EXDIR) $@

.PHONY: clangtest
clangtest: CFLAGS += -Werror -Wconversion -Wno-sign-conversion
clangtest: CC = clang
clangtest: clean
	$(CC) -v
	$(MAKE) -C $(LZ4DIR)  all CC=$(CC)
	$(MAKE) -C $(PRGDIR)  all CC=$(CC)
	$(MAKE) -C $(TESTDIR) all CC=$(CC)

.PHONY: clangtest-native
clangtest-native: CFLAGS = -O3 -Werror -Wconversion -Wno-sign-conversion
clangtest-native: clean
	clang -v
	$(MAKE) -C $(LZ4DIR)  all    CC=clang
	$(MAKE) -C $(PRGDIR)  native CC=clang
	$(MAKE) -C $(TESTDIR) native CC=clang

.PHONY: usan
usan: CC      = clang
usan: CFLAGS  = -O3 -g -fsanitize=undefined -fno-sanitize-recover=undefined -fsanitize-recover=pointer-overflow
usan: LDFLAGS = $(CFLAGS)
usan: clean
	CC=$(CC) CFLAGS='$(CFLAGS)' LDFLAGS='$(LDFLAGS)' $(MAKE) test FUZZER_TIME="-T30s" NB_LOOPS=-i1

.PHONY: usan32
usan32: CFLAGS = -m32 -O3 -g -fsanitize=undefined
usan32: LDFLAGS = $(CFLAGS)
usan32: clean
	$(MAKE) test FUZZER_TIME="-T30s" NB_LOOPS=-i1

SCANBUILD ?= scan-build
SCANBUILD_FLAGS += --status-bugs -v --force-analyze-debug-code
.PHONY: staticAnalyze
staticAnalyze: clean
	CPPFLAGS=-DLZ4_DEBUG=1 CFLAGS=-g $(SCANBUILD) $(SCANBUILD_FLAGS) $(MAKE) all V=1 DEBUGLEVEL=1

.PHONY: cppcheck
cppcheck:
	cppcheck . --force --enable=warning,portability,performance,style --error-exitcode=1 > /dev/null

.PHONY: platformTest
platformTest: clean
	@echo "\n ---- test lz4 with $(CC) compiler ----"
	$(CC) -v
	CFLAGS="-O3 -Werror"         $(MAKE) -C $(LZ4DIR) all
	CFLAGS="-O3 -Werror -static" $(MAKE) -C $(PRGDIR) all
	CFLAGS="-O3 -Werror -static" $(MAKE) -C $(TESTDIR) all
	$(MAKE) -C $(TESTDIR) test-platform

.PHONY: versionsTest
versionsTest: clean
	$(MAKE) -C $(TESTDIR) $@

.PHONY: cxxtest cxx32test
cxxtest cxx32test: CC := "$(CXX) -Wno-deprecated"
cxxtest cxx32test: CFLAGS = -O3 -Wall -Wextra -Wundef -Wshadow -Wcast-align -Werror
cxx32test: CFLAGS += -m32
cxxtest cxx32test: clean
	$(CXX) -v
	CC=$(CC) $(MAKE) -C $(LZ4DIR)  all CFLAGS="$(CFLAGS)"
	CC=$(CC) $(MAKE) -C $(PRGDIR)  all CFLAGS="$(CFLAGS)"
	CC=$(CC) $(MAKE) -C $(TESTDIR) all CFLAGS="$(CFLAGS)"

.PHONY: cxx17build
cxx17build : CC = "$(CXX) -Wno-deprecated"
cxx17build : CFLAGS = -std=c++17 -Wall -Wextra -Wundef -Wshadow -Wcast-align -Werror -pedantic
cxx17build : clean
	$(CXX) -v
	CC=$(CC) $(MAKE) -C $(LZ4DIR)  all CFLAGS="$(CFLAGS)"
	CC=$(CC) $(MAKE) -C $(PRGDIR)  all CFLAGS="$(CFLAGS)"
	CC=$(CC) $(MAKE) -C $(TESTDIR) all CFLAGS="$(CFLAGS)"

.PHONY: ctocpptest
ctocpptest: LIBCC="$(CC)"
ctocpptest: TESTCC="$(CXX)"
ctocpptest: CFLAGS=
ctocpptest: clean
	CC=$(LIBCC)  $(MAKE) -C $(LZ4DIR)  CFLAGS="$(CFLAGS)" all
	CC=$(LIBCC)  $(MAKE) -C $(TESTDIR) CFLAGS="$(CFLAGS)" lz4.o lz4hc.o lz4frame.o
	CC=$(TESTCC) $(MAKE) -C $(TESTDIR) CFLAGS="$(CFLAGS)" all

.PHONY: c_standards
c_standards: clean c_standards_c11 c_standards_c99 c_standards_c90

.PHONY: c_standards_c90
c_standards_c90: clean
	$(MAKE) clean; CFLAGS="-std=c90   -Werror -pedantic -Wno-long-long -Wno-variadic-macros" $(MAKE) allmost
	$(MAKE) clean; CFLAGS="-std=gnu90 -Werror -pedantic -Wno-long-long -Wno-variadic-macros" $(MAKE) allmost

.PHONY: c_standards_c99
c_standards_c99: clean
	$(MAKE) clean; CFLAGS="-std=c99   -Werror -pedantic" $(MAKE) all
	$(MAKE) clean; CFLAGS="-std=gnu99 -Werror -pedantic" $(MAKE) all

.PHONY: c_standards_c11
c_standards_c11: clean
	$(MAKE) clean; CFLAGS="-std=c11 -Werror" $(MAKE) all

# The following test ensures that standard Makefile variables set through environment
# are correctly transmitted at compilation stage.
# This test is meant to detect issues like https://github.com/lz4/lz4/issues/958
.PHONY: standard_variables
standard_variables: clean
	@echo =================
	@echo Check support of Makefile Standard variables through environment
	@echo note : this test requires V=1 to work properly
	@echo =================
	CC="cc -DCC_TEST" \
	CFLAGS=-DCFLAGS_TEST \
	CPPFLAGS=-DCPPFLAGS_TEST \
	LDFLAGS=-DLDFLAGS_TEST \
	LDLIBS=-DLDLIBS_TEST \
	$(MAKE) V=1 > tmpsv
	# Note: just checking the presence of custom flags
	# would not detect situations where custom flags are
	# supported in some part of the Makefile, and missed in others.
	# So the test checks if they are present the _right nb of times_.
	# However, checking static quantities makes this test brittle,
	# because quantities (7, 2 and 1) can still evolve in future,
	# for example when source directories or Makefile evolve.
	if [ $$(grep CC_TEST tmpsv | wc -l) -ne 7 ]; then \
		echo "CC environment variable missed" && False; fi
	if [ $$(grep CFLAGS_TEST tmpsv | wc -l) -ne 7 ]; then \
		echo "CFLAGS environment variable missed" && False; fi
	if [ $$(grep CPPFLAGS_TEST tmpsv | wc -l) -ne 7 ]; then \
		echo "CPPFLAGS environment variable missed" && False; fi
	if [ $$(grep LDFLAGS_TEST tmpsv | wc -l) -ne 2 ]; then \
		echo "LDFLAGS environment variable missed" && False; fi
	if [ $$(grep LDLIBS_TEST tmpsv | wc -l) -ne 1 ]; then \
		echo "LDLIBS environment variable missed" && False; fi
	@echo =================
	@echo all custom variables detected
	@echo =================
	$(RM) tmpsv

endif   # MSYS POSIX
