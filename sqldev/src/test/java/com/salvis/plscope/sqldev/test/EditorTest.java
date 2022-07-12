package com.salvis.plscope.sqldev.test;

import org.junit.jupiter.api.*;
import org.w3c.dom.Document;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import java.io.IOException;

/**
 * compare report queries with there relational view counterpart which are not used in the SQLDev extension
 */
public class EditorTest extends AbstractJdbcTest{

    private static final XMLTools xmlTools = new XMLTools();
    private static final DocumentBuilder docBuilder = xmlTools.createDocumentBuilder();
    private static Document doc;

    @BeforeAll
    public static void setup() throws IOException, SAXException {
        var url = Thread.currentThread().getContextClassLoader().getResource("com/salvis/plscope/sqldev/editor/plscope-utils-viewers.xml");
        assert url != null;
        doc = docBuilder.parse(url.openStream());
    }

    @Nested
    class Identifiers {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Identifiers']/queries/query[@minversion=12.2]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_identifiers
                         where object_type like 'PACKAGE%'
                           and object_name = 'ETL'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Identifiers']/queries/query[@minversion=11.1]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_identifiers
                         where object_type like 'PACKAGE%'
                           and object_name = 'ETL'
                           and usage != 'EXECUTE'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class Statements {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Statements']/queries/query[@minversion=12.2]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_statements
                         where object_type like 'PACKAGE%'
                           and object_name = 'ETL'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class Uses {

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Uses']/queries/query[@minversion=11.1]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_identifiers
                         where object_type like 'PACKAGE%'
                           and object_name = 'ETL'
                           and not (
                                  ref_owner = user
                                  and ref_object_type in ('PACKAGE', 'PACKAGE BODY')
                                  and ref_object_name = 'ETL'
                               )
                           and not (
                                  ref_owner = 'SYS'
                                  and ref_object_type = 'PACKAGE'
                                  and ref_object_name = 'STANDARD'
                               )
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class Used_by {

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Used by']/queries/query[@minversion=11.1]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select refs.*
                          from plscope_identifiers refs
                          join plscope_identifiers ids
                            on ids.signature = refs.signature
                         where refs.object_type like 'PACKAGE%'
                           and refs.object_name = 'ETL'
                           and refs.usage = 'DECLARATION'
                           and not (
                                  ids.owner = user
                                  and ids.object_type in ('PACKAGE', 'PACKAGE BODY')
                                  and ids.object_name = 'ETL'
                               )
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class Table_Usages {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Table Usages']/queries/query[@minversion=12.2]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            // resolve synonyms as indirect dependencies only (do not resolve table usages in views)
            var extendedQuery = "select * from (" + query + ") where \"Direct dep?\" = 'YES'";
            var actual = jdbcTemplate.queryForList(extendedQuery);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_tab_usage
                         where object_type like 'PACKAGE%'
                           and object_name = 'ETL'
                           and direct_dependency = 'YES'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class Column_Usages {

        @Test
        public void query122() {
            var node = xmlTools.getNode(doc, "/displays/display[name='Column Usages']/queries/query[@minversion=12.2]/sql");
            var query = node.getTextContent()
                    .replaceAll(":OBJECT_OWNER", "user")
                    .replaceAll(":OBJECT_TYPE", "'plscope-utils-package'")
                    .replaceAll(":OBJECT_NAME", "'ETL'");
            // resolve synonyms as indirect dependencies only (do not resolve table usages in views)
            var extendedQuery = "select * from (" + query + ") where \"Direct dep?\" = 'YES'";
            var actual = jdbcTemplate.queryForList(extendedQuery);
            var expected = jdbcTemplate.queryForList("""
                        select *
                          from plscope_col_usage
                         where object_type like 'PACKAGE%'
                           and object_name = 'ETL'
                           and direct_dependency = 'YES'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }
}
