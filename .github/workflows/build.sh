#!/bin/bash

function run_tests_local() {
    cat >/tmp/update_plscope.sql <<EOF
connect plscope/plscope@xepdb1
@install.sql
@install_test.sql
exit
EOF

    $BUILD_DIR/../../.tools/sqlcl/bin/sql -nolog @/tmp/update_plscope.sql

    # run tests with code coverage via utPLSQL-cli
    export JAVA_TOOL_OPTIONS="-DTNS_ADMIN=/etc"
    ../.tools/utPLSQL-cli/bin/utplsql run plscope/plscope@xepdb1 \
    -source_path=utils -owner=plscope \
    -p='plscope' \
    -test_path=test \
    -f=ut_coverage_sonar_reporter     -o=coverage.xml \
    -f=ut_coverage_html_reporter      -o=coverage.html \
    -f=ut_sonar_test_reporter         -o=test_results.xml \
    -f=ut_junit_reporter              -o=junit_test_results.xml \
    -f=ut_documentation_reporter      -o=test_results.log -s
}

# main
BUILD_DIR="$(dirname $0)"
cd $BUILD_DIR/../../database
if [ "$1" == "" ] | [ "$1" == "cloud" ] ; then
    $BUILD_DIR/run_tests.sh
    $BUILD_DIR/create_codecop_issues.sh
    sonar-scanner -Dsonar.host.url=https://sonarcloud.io
elif [ "$1" == "local" ] ; then
    run_tests_local
    $BUILD_DIR/create_codecop_issues.sh
    sonar-scanner -Dsonar.host.url=https://sonarcloud.io
else
    PORT=$1
    JSON=$2
    run_tests_local
    if [ $JSON == "json" ]; then
        $BUILD_DIR/create_codecop_issues.sh
    else
        echo '{"issues": []}' > tvdcc_report.json
    fi
    sonar-scanner -Dsonar.host.url=http://localhost:$PORT -Dsonar.login=admin -Dsonar.password=oracle
fi
