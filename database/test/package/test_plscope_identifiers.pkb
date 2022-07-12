create or replace package body test_plscope_identifiers is

   procedure user_identifiers is
      c_actual   sys_refcursor;
      c_expected sys_refcursor;
   begin
      -- populate actual
      open c_actual for
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
      open c_expected for
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
           from sys.user_identifiers -- NOSONAR: avoid public synonym
          where object_name = 'DD_UTIL'
          order by object_type, object_name, line, col, usage, usage_id;

      -- assert
      ut.expect(c_actual).to_equal(c_expected).join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE, USAGE_ID')
      .exclude('USAGE_CONTEXT_ID');
   end user_identifiers;

   procedure user_statements is
      c_actual   sys_refcursor;
      c_expected sys_refcursor;
   begin
      -- populate actual
      open c_actual for
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
      open c_expected for
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
           from sys.user_statements -- NOSONAR: avoid public synonym
          order by object_type, object_name, line, col, usage_id;

      -- assert
      ut.expect(c_actual).to_equal(c_expected).join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE_ID')
      .exclude('USAGE_CONTEXT_ID, TEXT');
   end user_statements;

end test_plscope_identifiers;
/
