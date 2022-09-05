#!/bin/bash

# Remove .tools directory with all its content to simplify updates
BUILD_DIR="$(dirname $0)"
rm -rf $BUILD_DIR/../../.tools
mkdir $BUILD_DIR/../../.tools
cd $BUILD_DIR/../../.tools

# install latest sqlcl version
curl -Lk -o sqlcl-latest.zip https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip
unzip sqlcl-latest.zip -d .

# install latest utPLSQL-cli version
export UTPLSQL_CLI_VERSION=3.1.9
curl -Lk -o utPLSQL-cli.zip https://github.com/utPLSQL/utPLSQL-cli/releases/download/$UTPLSQL_CLI_VERSION/utPLSQL-cli.zip
unzip utPLSQL-cli.zip -d .

# install latest db* CODECOP CLI
export COP_VERSION=4.3.0
curl -Lk -o tvdcc.zip https://github.com/Trivadis/plsql-cop-cli/releases/download/v$COP_VERSION/tvdcc-$COP_VERSION.zip
unzip tvdcc.zip -d .
mv tvdcc-$COP_VERSION tvdcc

# install latest db* CODECOP custom validator TrivadisGuidelines3Plus
export VALIDATOR_VERSION=4.3.0
curl -Lk -o tvdcc/plugin/sonar-plsql-cop-custom-validators-plugin-$VALIDATOR_VERSION.jar https://github.com/Trivadis/plsql-cop-validators/releases/download/v$VALIDATOR_VERSION/sonar-plsql-cop-custom-validators-plugin-$VALIDATOR_VERSION.jar

# install db* CODECOP license from Base64 encoded environment variable
echo $TVDCC_LIC | base64 -d > tvdcc/tvdcc.lic

# install wallet to access ATP from Base64 encoded environment variable
echo $WALLET | base64 -d > wallet.zip
unzip wallet.zip -d wallet
