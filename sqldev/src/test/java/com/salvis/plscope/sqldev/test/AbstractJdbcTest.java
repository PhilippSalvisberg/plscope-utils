package com.salvis.plscope.sqldev.test;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

import java.io.IOException;
import java.util.Properties;

public abstract class AbstractJdbcTest {
    protected static final SingleConnectionDataSource dataSource;
    protected static final JdbcTemplate jdbcTemplate;

    static {
        final Properties p = new Properties();
        try {
            p.load(AbstractJdbcTest.class.getResourceAsStream("/test.properties"));
        } catch (IOException e) {
            throw new RuntimeException("Cannot read test.properties", e);
        }
        // create dataSource and jdbcTemplate
        dataSource = new SingleConnectionDataSource();
        dataSource.setDriverClassName("oracle.jdbc.OracleDriver");
        dataSource.setUrl("jdbc:oracle:thin:@" + p.getProperty("host") + ":" + p.getProperty("port") + "/"
                + p.getProperty("service"));
        dataSource.setUsername(p.getProperty("username"));
        dataSource.setPassword(p.getProperty("password"));
        jdbcTemplate = new JdbcTemplate(dataSource);
    }
}
