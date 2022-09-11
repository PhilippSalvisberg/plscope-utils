package com.salvis.plscope.sqldev.test;

import org.junit.jupiter.api.*;
import org.w3c.dom.Document;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import java.io.IOException;

public class ActionTest extends AbstractJdbcTest{

    private static final XMLTools xmlTools = new XMLTools();
    private static final DocumentBuilder docBuilder = xmlTools.createDocumentBuilder();
    private static Document doc;

    @BeforeAll
    public static void setup() throws IOException, SAXException {
        var url = Thread.currentThread().getContextClassLoader().getResource("com/salvis/plscope/sqldev/action/compile_with_plscope.xml");
        assert url != null;
        doc = docBuilder.parse(url.openStream());
    }

    @Nested
    class Compile_with_PLScope {

        @Test
        public void connection_node() {
            var node = xmlTools.getNode(doc, "//*[local-name()='item'][@type='CONNECTION']/*[local-name()='sql']");
            var query = node.getTextContent()
                    .replaceAll("#0#", "All")
                    .replaceAll("#1#", "ALL")
                    .replaceAll("#2#", "ALL")
                    .replaceAll("#3#", "Yes, reuse settings")
                    .replaceAll("#4#", "Yes")
                    .replaceAll("#5#", "Yes")
                    .replaceAll("#6#", "On - All details")
                    .replaceAll("#\"OBJECT_OWNER\"#", "\"" + dataSource.getUsername() + "\"");
            // ok if no exception is thrown
            jdbcTemplate.update(query);
        }

        @Test
        public void plscope_util_root_node() {
            var node = xmlTools.getNode(doc, "//*[local-name()='item'][@type='plscope-utils-root']/*[local-name()='sql']");
            var query = node.getTextContent()
                    .replaceAll("#0#", "All")
                    .replaceAll("#1#", "ALL")
                    .replaceAll("#2#", "ALL")
                    .replaceAll("#3#", "No")
                    .replaceAll("#4#", "No")
                    .replaceAll("#5#", "No")
                    .replaceAll("#6#", "Off")
                    .replaceAll("#\"OBJECT_OWNER\"#", "\"" + dataSource.getUsername() + "\"");
            // ok if no exception is thrown
            jdbcTemplate.update(query);
        }
    }
}
