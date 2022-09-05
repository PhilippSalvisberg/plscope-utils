#!/bin/bash

function run_tests() {
    DB_USER=$1
    DB_PASS=$2
    DB=$3
    TNS_ADMIN=$4

    cat >/tmp/update.sql <<EOF
set cloudconfig ../.tools/wallet.zip
connect $DB_USER/$DB_PASS@$DB
@install.sql
@install_test.sql
exit
EOF

    # install code and tests
    ../.tools/sqlcl/bin/sql -nolog @/tmp/update.sql

    # run tests with code coverage
    export JAVA_TOOL_OPTIONS="-DTNS_ADMIN=$TNS_ADMIN"
    ../.tools/utPLSQL-cli/bin/utplsql run $DB_USER/$DB_PASS@$DB \
    -source_path=utils -owner=$DB_USER \
    -p='plscope' \
    -test_path=test \
    -f=ut_coverage_sonar_reporter     -o=coverage.xml \
    -f=ut_coverage_html_reporter      -o=coverage.html \
    -f=ut_sonar_test_reporter         -o=test_results.xml \
    -f=ut_junit_reporter              -o=junit_test_results.xml \
    -f=ut_documentation_reporter      -o=test_results.log -s
    export JAVA_TOOL_OPTIONS=
}

function create_codecop_issues() {
    # skipping the following issues since quality profiles are not supported for
    # issues reported in generic issue import format:
    # - G-0000: Avoid using the NOSONAR marker.
    # - G-1050: Avoid using literals in your code.
    # - G-2130: Try to use subtypes for constructs used often in your code.
    # - G-5010: Try to use a error/logging framework for your application.
    # - G-7460: Try to define your packaged/standalone function deterministic if appropriate.
    # - G-8310: Always validate input parameter size by assigning the parameter to a size limited variable in the declaration section of program unit.
    ../.tools/tvdcc/tvdcc.sh \
        path=utils \
        html=false \
        excel=false \
        json=true \
        skip=0,1050,2130,5010,7460,8310 \
        validator=com.trivadis.tvdcc.validators.TrivadisGuidelines3Plus
}

# main
BUILD_DIR="$(dirname $0)"
SONAR_PORT="${1:-cloud}"
DB="${2:-xepdb1}"
DB_USER="plscope"
DB_PASS="${3:-plscope}"
CREATE_CODECOP_ISSUES="${4:-false}"
if [ "$DB" == "atp21_high" ]; then 
    TNS_ADMIN="../.tools/wallet"
else 
    TNS_ADMIN="/etc"
fi
cd $BUILD_DIR/../../database
if [ "$CI" == "true" ]; then
    echo "SonarCloud using ATP (via GitHub Actions)"
    run_tests "$DB_USER" "$PLSCOPE_PW" "atp21_high" "../.tools/wallet"
    echo "Creating db* CODECOP issues"
    create_codecop_issues
elif [ "$SONAR_PORT" == "cloud" ] ; then
    echo "SonarCloud using $DB (running build.sh locally)"
    run_tests "$DB_USER" "$DB_PASS" "$DB" "$TNS_ADMIN"
    echo "Creating db* CODECOP issues"
    create_codecop_issues
    echo "Run sonar-scanner"
    sonar-scanner -Dsonar.host.url=https://sonarcloud.io
else
    echo "SonarQube on http://localhost:$SONAR_PORT using $DB"
    run_tests "$DB_USER" "$DB_PASS" "$DB" "$TNS_ADMIN"
    if [ $CREATE_CODECOP_ISSUES == "true" ]; then
        echo "Creating db* CODECOP issues"
        create_codecop_issues
    else
        echo "No db* CODECOP issues"
        echo '{"issues": []}' > tvdcc_report.json
    fi
    echo "Run sonar-scanner"
    sonar-scanner -Dsonar.host.url=http://localhost:$SONAR_PORT -Dsonar.login=admin -Dsonar.password=oracle
fi
