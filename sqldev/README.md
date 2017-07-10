# plscope-utils - SQL Developer Extension (plscope-utils for SQL Developer)

## Introduction
This component of plscope-utils extends SQL Developer by the following:

- ```PL/Scope```node in the database navigator tree;
- ```Compile with PL/Scope``` context menu on the connection and PL/Scope node;
- ```Identifiers```, ```Statements```, ```Used by```, ```Table Usages```and ```Column Usages``` viewers shown for tables, views and PL/SQL nodes;
- ```CRUD Operations```, ```Duplicate SQL Statements```, ```UDF Calls in SQL Statements``` and ```Unused Local Identifiers```reports.

Requires a client side installation only. All operations are based on components available in an Oracle Database Server version 11.1. However, viewers and reports querying the ```all_statements``` view require an Oracle Database version 12.2 or higher.

See https://www.salvis.com/blog/plscope-utils-for-sql-developer/ for screenshots and download links.

## Prerequisites

* Oracle Database 11.1 or higher
* Oracle SQL Developer 4.0 or higher

## How to Build

1. [Download](http://www.oracle.com/technetwork/developer-tools/sql-developer/downloads/index.html) and install SQL Developer 4.2.0
2. [Download](https://maven.apache.org/download.cgi) and install Apache Maven 3.5.0
3. [Download](https://git-scm.com/downloads) and install a git command line client
4. Clone the plscope-utils repository
5. Open a terminal window in the plscope-utils root folder and type

		cd sqldev

6. Run maven build by the following command

		mvn -Dsqldev.basedir=/Applications/SQLDeveloper4.2.0.app/Contents/Resources/sqldeveloper clean package

	Amend the parameter sqldev.basedir to match the path of your SQL Developer installation. This folder is used to reference Oracle jar files which are not available in public Maven repositories
7. The resulting file ```plscope-utils_for_SQLDev_x.x.x-SNAPSHOT.zip``` in the ```target``` directory may be installed within SQL Developer

## Installation

### From file

1. Start SQL Developer

2. Select ```Check for Updates…``` in the help menu.

3. Use the ```Install From Local File``` option to install the previously downloaded ```plscope-utils_for_SQLDev_*.zip``` file.

### Via Update Center

1. Start SQL Developer

2. Select ```Check for Updates…``` in the help menu.

3. Press ```Add…``` to register the salvis.com update site http://update.salvis.com/.

4. Use the ```Search Update Center``` option and select the ```salvis.com update``` center to install the lastest version of ```plscope-utils for SQL Developer```.

## License

plscope-utils is licensed under the Apache License, Version 2.0. You may obtain a copy of the License at <http://www.apache.org/licenses/LICENSE-2.0>.
