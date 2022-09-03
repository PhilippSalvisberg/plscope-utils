package com.salvis.plscope.sqldev.test;

import org.junit.jupiter.api.*;
import org.w3c.dom.Document;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import java.io.IOException;

/**
 * compare report queries with there relational view counterpart which are not used in the SQLDev extension
 */
public class ReportTest extends AbstractJdbcTest{

    private static final XMLTools xmlTools = new XMLTools();
    private static final DocumentBuilder docBuilder = xmlTools.createDocumentBuilder();
    private static Document doc;

    @BeforeAll
    public static void setup() throws IOException, SAXException {
        var url = Thread.currentThread().getContextClassLoader().getResource("com/salvis/plscope/sqldev/report/plscope-utils-reports.xml");
        assert url != null;
        doc = docBuilder.parse(url.openStream());
    }

    @Nested
    class Duplicate_SQL_Statements {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/folder/folder/display[name='Duplicate SQL Statements']/query[@minversion='12.2']/sql");
            var query = node.getTextContent().replaceAll(":[A-Z_]+", "null");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_statements
                         where is_duplicate = 'YES'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class UDF_Calls_in_SQL_Statements {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/folder/folder/display[name='UDF Calls in SQL Statements']/query[@minversion='12.2']/sql");
            var query = node.getTextContent().replaceAll(":[A-Z_]+", "null");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_identifiers
                         where parent_statement_type in ('SELECT', 'INSERT', 'UPDATE', 'DETETE', 'MERGE')
                           and type = 'FUNCTION'
                           and usage = 'CALL'
                           -- ensure function call is part of the parent statement
                           and (parent_statement_path_len >= path_len - 2)
                           -- do not report function calls from standard package such as USER, REPLACE, SUBSTR, etc.
                           and not (ref_owner = 'SYS' and ref_object_type = 'PACKAGE' and ref_object_name = 'STANDARD')
                         order by owner, object_type, object_name, line, col
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class CRUD_Operations {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/folder/folder/display[name='CRUD Operations']/query[@minversion='12.2']/sql");
            var query = node.getTextContent().replaceAll(":[A-Z_]+", "null");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select owner, object_type, object_name, procedure_name, ref_owner, ref_object_type, ref_object_name
                          from plscope_tab_usage
                         where operation in ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'MERGE', 'REFERENCE')
                           and direct_dependency = 'YES'
                           and (ref_owner, ref_object_type, ref_object_name) in (
                                  select owner, object_type, object_name
                                    from all_identifiers
                               )
                         group by owner, object_type, object_name, procedure_name, ref_owner, ref_object_type, ref_object_name
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class Unused_Local_Identifiers {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/folder/folder/display[name='Unused Local Identifiers']/query[@minversion='12.2']/sql");
            var query = node.getTextContent().replaceAll(":[A-Z_]+", "null");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_identifiers
                         where usage = 'DECLARATION'
                           and is_used = 'NO'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/displays/folder/folder/display[name='Unused Local Identifiers']/query[@minversion='11.1']/sql");
            var query = node.getTextContent().replaceAll(":[A-Z_]+", "null");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_identifiers
                         where usage = 'DECLARATION'
                           and is_used = 'NO'
                    """);
            // 12.2 view considers usage in SQL but 11.1 query not, as a result a difference is expected
            Assertions.assertTrue(actual.size() >= expected.size());
        }
    }

    @Nested
    class PLSQL_Naming_Conventions {

        @BeforeEach
        public void setup() {
            jdbcTemplate.update("""
                        begin
                           plscope_context.set_attr('LOCAL_VARIABLE_REGEX', '^x_.*');
                        end;
                    """);
        }

        @AfterEach
        public void teardown() {
            jdbcTemplate.update("""
                        begin
                           plscope_context.remove_all;
                        end;
                    """);
        }

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/displays/folder/folder/display[name='PL/SQL Naming Conventions']/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":LOCAL_VARIABLE_REGEX", "'^x_.*'")
                    .replaceAll(":[A-Z_]+", "null");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_naming
                         where message != 'OK'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }
}
