package com.salvis.plscope.sqldev.test;

import org.junit.jupiter.api.*;
import org.w3c.dom.Document;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import java.io.IOException;

public class NavigatorTest extends AbstractJdbcTest{

    private static final XMLTools xmlTools = new XMLTools();
    private static final DocumentBuilder docBuilder = xmlTools.createDocumentBuilder();
    private static Document doc;

    @BeforeAll
    public static void setup() throws IOException, SAXException {
        var url = Thread.currentThread().getContextClassLoader().getResource("com/salvis/plscope/sqldev/navigator/plscope-utils-nodes.xml");
        assert url != null;
        doc = docBuilder.parse(url.openStream());
    }

    @Nested
    class plscope_utils_package {

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-package'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'PACKAGE'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_procedure {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-procedure'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'PROCEDURE'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_function {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-function'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'FUNCTION'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_trigger {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-trigger'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'TRIGGER'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_type {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-type'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'TYPE'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_priv_syn {

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-priv-syn']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-priv-syn'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select i.object_name
                          from sys.all_identifiers i
                          join sys.all_synonyms s
                            on i.owner = s.owner
                           and i.object_name = s.synonym_name
                         where i.usage = 'DECLARATION'
                           and i.usage_context_id = 0
                           and i.owner = user
                           and i.object_type = 'SYNONYM'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_pub_syn {

        @Test
        public void query111() {
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-pub-syn']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-pub-syn'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select i.object_name
                          from sys.all_identifiers i
                          join sys.all_synonyms s
                            on i.owner = s.owner
                           and i.object_name = s.synonym_name
                         where i.usage = 'DECLARATION'
                           and i.usage_context_id = 0
                           and i.owner = 'PUBLIC'
                           and i.object_type = 'SYNONYM'
                           and s.table_owner = user
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_table {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-table'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'TABLE'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_view {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-view'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'VIEW'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }

    @Nested
    class plscope_utils_sequence {

        @Test
        public void query111() {
            // shared query id
            var node = xmlTools.getNode(doc, "/navigator/objectType[@id='plscope-utils-package']/folder/queries/query[@minversion='11.1']/sql");
            var query = node.getTextContent()
                    .replaceAll(":SCHEMA", "user")
                    .replaceAll(":TYPE", "'plscope-utils-sequence'");
            var actual = jdbcTemplate.queryForList(query);
            var expected = jdbcTemplate.queryForList("""
                        select object_name
                          from sys.all_identifiers
                         where usage = 'DECLARATION'
                           and usage_context_id = 0
                           and owner = user
                           and object_type = 'SEQUENCE'
                    """);
            Assertions.assertEquals(expected.size(), actual.size());
        }
    }
}
