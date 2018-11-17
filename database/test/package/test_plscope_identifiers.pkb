CREATE OR REPLACE PACKAGE BODY test_plscope_identifiers IS

   PROCEDURE user_identifiers IS
      l_actual   sys_refcursor;
      l_expected sys_refcursor;
   BEGIN
      -- populate actual
      OPEN l_actual for 
         SELECT object_type, object_name, line, col, name, type, usage, 
                signature, usage_id, usage_context_id, origin_con_id
           FROM plscope_identifiers
          WHERE usage != 'EXECUTE' -- exclude SQL
            AND object_name = 'DD_UTIL'
          ORDER BY object_type, object_name, line, col, usage, usage_id;

      -- populate expected
      OPEN l_expected FOR 
         SELECT object_type, object_name, line, col, name, type, usage, 
                signature, usage_id, usage_context_id, origin_con_id
           FROM user_identifiers 
          WHERE object_name = 'DD_UTIL'
          ORDER BY object_type, object_name, line, col, usage, usage_id;

      -- assert
      ut.expect(l_actual).to_equal(l_expected)
         .join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE, USAGE_ID')
         .exclude('USAGE_CONTEXT_ID');
   END user_identifiers;

   PROCEDURE user_statements IS
      l_actual   sys_refcursor;
      l_expected sys_refcursor;
   BEGIN
      -- populate actual
      OPEN l_actual FOR
         SELECT object_type, object_name, line, col, type, text,
                signature, usage_id, usage_context_id, origin_con_id
           FROM plscope_identifiers
          WHERE usage = 'EXECUTE' -- SQL
          ORDER BY object_type, object_name, line, col, usage_id;

      -- populate expected
      OPEN l_expected FOR 
         SELECT object_type, object_name, line, col, type, text,
                signature, usage_id, usage_context_id, origin_con_id
           FROM user_statements
          ORDER BY object_type, object_name, line, col, usage_id;

      -- assert
      ut.expect(l_actual).to_equal(l_expected)
         .join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE_ID')
         .exclude('USAGE_CONTEXT_ID, TEXT');
   END user_statements;

   
END test_plscope_identifiers;
/
