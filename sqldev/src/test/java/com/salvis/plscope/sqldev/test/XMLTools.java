package com.salvis.plscope.sqldev.test;

import org.w3c.dom.*;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.*;
import java.io.IOException;
import java.io.StringWriter;

/**
 * based on https://github.com/utPLSQL/utPLSQL-SQLDeveloper/blob/beed2c2541533ed3c9933fcf9cba45e3891af6ac/sqldev/src/main/java/org/utplsql/sqldev/model/URLTools.java
 */
public class XMLTools {
    private final XPathFactory xpathFactory = XPathFactory.newInstance();
    private final XPath xpath = xpathFactory.newXPath();

    public NodeList getNodeList(final Node doc, final String xpathString) {
        try {
            final XPathExpression expr = xpath.compile(xpathString);
            return ((NodeList) expr.evaluate(doc, XPathConstants.NODESET));
        } catch (XPathExpressionException e) {
            final String msg = "XPathExpressionException for " + xpathString + ".";
            throw new RuntimeException(msg, e);
        }
    }

    public Node getNode(final Node doc, final String xpathString) {
        try {
            final XPathExpression expr = xpath.compile(xpathString);
            return ((Node) expr.evaluate(doc, XPathConstants.NODE));
        } catch (XPathExpressionException e) {
            final String msg = "XPathExpressionException for " + xpathString + ".";
            throw new RuntimeException(msg, e);
        }
    }

    public void trimWhitespace(final Node node) {
        final NodeList children = node.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            final Node child = children.item(i);
            if (child.getNodeType() == Node.TEXT_NODE) {
                child.setTextContent(child.getTextContent().trim());
            }
            trimWhitespace(child);
        }
    }

    public String nodeToString(final Node node, final String cdataSectionElements) {
        try {
            trimWhitespace(node);
            final StringWriter writer = new StringWriter();
            TransformerFactory factory = TransformerFactory.newInstance();
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            final Transformer transformer = factory.newTransformer();
            transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "yes");
            transformer.setOutputProperty(OutputKeys.INDENT, "yes");
            transformer.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "3");
            transformer.setOutputProperty(OutputKeys.CDATA_SECTION_ELEMENTS, cdataSectionElements);
            transformer.transform( new DOMSource(node), new StreamResult(writer));
            final String result = writer.toString();
            return result.replaceAll("<!\\[CDATA\\[\\s*\\]\\]>", "");
        } catch (TransformerException e) {
            final String msg = "TransformerException for " + cdataSectionElements + ".";
            throw new RuntimeException(msg, e);
        }
    }

    public String getAttributeValue(final Node node, final String namedItem) {
        String value = null;
        if (node instanceof Element) {
            final NamedNodeMap attributes = node.getAttributes();
            if (attributes != null) {
                final Node item = attributes.getNamedItem(namedItem);
                if (item != null) {
                    value = item.getNodeValue();
                }
            }
        }
        return value;
    }

    public String getElementValue(final Node node, final String tagName) {
        String value = null;
        final Node item = getElementNode(node, tagName);
        if (item != null) {
            value = item.getTextContent();
        }
        return value;
    }

    public Node getElementNode(final Node node, final String tagName) {
        Node resultNode = null;
        if (node instanceof Element) {
            NodeList list = ((Element) node).getElementsByTagName(tagName);
            if (list != null && list.getLength() > 0 && list.item(0).getParentNode() == node) {
                resultNode = list.item(0);
            }
        }
        return resultNode;
    }

    public DocumentBuilder createDocumentBuilder() {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        try {
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, Boolean.TRUE);
            return factory.newDocumentBuilder();
        } catch (ParserConfigurationException e) {
            final String msg = "Could not create no document builder.";
            throw new RuntimeException(msg, e);
        }
    }

    public Document parse(final DocumentBuilder builder, final InputSource inputSource) {
        try {
            return builder.parse(inputSource);
        } catch (SAXException | IOException e) {
            final String msg = "Could not parse XML input.";
            throw new RuntimeException(msg, e);
        }
    }
}
