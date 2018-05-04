#!/bin/sh

NAME=Sys-Virt

set -e

test -n "$1" && RESULTS=$1 || RESULTS=results.log

make -k realclean ||:
rm -rf MANIFEST blib pm_to_blib

export TEST_MAINTAINER=1

perl Makefile.PL PREFIX=$HOME/builder

rm -f MANIFEST

# Build the RPM.
make
make manifest

if [ -z "$USE_COVER" ]; then
  perl -MDevel::Cover -e '' 1>/dev/null 2>&1 && USE_COVER=1 || USE_COVER=0
fi

if [ -z "$SKIP_TESTS" -o "$SKIP_TESTS" = "0" ]; then
  if [ "$USE_COVER" = "1" ]; then
    cover -delete
    export HARNESS_PERL_SWITCHES=-MDevel::Cover
  fi

  # set -o pipefail is a bashism; this use of exec is the POSIX alternative
  exec 3>&1
  st=$(
      exec 4>&1 >&3
      { make test 2>&1 3>&- 4>&-; echo $? >&4; } | tee "$RESULTS"
  )
  exec 3>&-
  test "$st" = 0

  if [ "$USE_COVER" = "1" ]; then
    cover
    mkdir blib/coverage
    cp -a cover_db/*.html cover_db/*.css blib/coverage
    mv blib/coverage/coverage.html blib/coverage/index.html
  fi
fi

make install

rm -f $NAME-*.tar.gz
make dist

if [ -f /usr/bin/rpmbuild ]; then
  rpmbuild --nodeps -ta --clean $NAME-*.tar.gz
fi
