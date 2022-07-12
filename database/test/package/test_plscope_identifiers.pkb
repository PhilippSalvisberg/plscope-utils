create or replace package body test_plscope_identifiers is

   procedure user_identifiers is
      l_actual   sys_refcursor;
      l_expected sys_refcursor;
   begin
      -- populate actual
      open l_actual for
         select object_type,
                object_name,
                line,
                col,
                name,
                type,
                usage,
                signature,
                usage_id,
                usage_context_id,
                origin_con_id
           from plscope_identifiers
          where usage != 'EXECUTE' -- exclude SQL
            and object_name = 'DD_UTIL'
          order by object_type, object_name, line, col, usage, usage_id;

      -- populate expected
      open l_expected for
         select object_type,
                object_name,
                line,
                col,
                name,
                type,
                usage,
                signature,
                usage_id,
                usage_context_id,
                origin_con_id
           from sys.user_identifiers
          where object_name = 'DD_UTIL'
          order by object_type, object_name, line, col, usage, usage_id;

      -- assert
      ut.expect(l_actual).to_equal(l_expected).join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE, USAGE_ID')
      .exclude('USAGE_CONTEXT_ID');
   end user_identifiers;

   procedure user_statements is
      l_actual   sys_refcursor;
      l_expected sys_refcursor;
   begin
      -- populate actual
      open l_actual for
         select object_type,
                object_name,
                line,
                col,
                type,
                text,
                signature,
                usage_id,
                usage_context_id,
                origin_con_id
           from plscope_identifiers
          where usage = 'EXECUTE' -- SQL
          order by object_type, object_name, line, col, usage_id;

      -- populate expected
      open l_expected for
         select object_type,
                object_name,
                line,
                col,
                type,
                text,
                signature,
                usage_id,
                usage_context_id,
                origin_con_id
           from sys.user_statements
          order by object_type, object_name, line, col, usage_id;

      -- assert
      ut.expect(l_actual).to_equal(l_expected).join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE_ID')
      .exclude('USAGE_CONTEXT_ID, TEXT');
   end user_statements;

end test_plscope_identifiers;
/
