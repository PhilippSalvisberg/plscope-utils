#!/bin/bash

# Install plscope-utils code and test
BUILD_DIR="$(dirname $0)"
cd $BUILD_DIR/../../database

cat >/tmp/update_plscope.sql <<EOF
set cloudconfig ../.tools/wallet.zip
connect plscope/$PLSCOPE_PW@atp21_high
@install.sql
@install_test.sql
exit
EOF

../.tools/sqlcl/bin/sql -nolog @/tmp/update_plscope.sql

# run tests with code coverage via utPLSQL-cli
export JAVA_TOOL_OPTIONS="-DTNS_ADMIN=../.tools/wallet"
../.tools/utPLSQL-cli/bin/utplsql run plscope/$PLSCOPE_PW@atp21_high \
-source_path=utils -owner=plscope \
-p='plscope' \
-test_path=test \
-f=ut_coverage_sonar_reporter     -o=coverage.xml \
-f=ut_coverage_html_reporter      -o=coverage.html \
-f=ut_sonar_test_reporter         -o=test_results.xml \
-f=ut_junit_reporter              -o=junit_test_results.xml \
-f=ut_documentation_reporter      -o=test_results.log -s
