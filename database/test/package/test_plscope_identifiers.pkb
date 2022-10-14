create or replace package body test_plscope_identifiers is

   co_plsql_unit_owner constant user_users.username%type := $$PLSQL_UNIT_OWNER;

   procedure set_context is
   begin
      if sys_context('USERENV', 'CURRENT_USER') <> co_plsql_unit_owner then
         plscope_context.set_attr('OWNER', co_plsql_unit_owner);
      end if;
   end set_context;
   
   procedure clear_context is
   begin
      if sys_context('USERENV', 'CURRENT_USER') <> co_plsql_unit_owner then
         plscope_context.remove_all;
      end if;
   end clear_context;

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
           from sys.all_identifiers -- NOSONAR: avoid public synonym
          where owner = co_plsql_unit_owner
            and object_name = 'DD_UTIL'
          order by object_type, object_name, line, col, usage, usage_id;

      -- assert
      ut.expect(c_actual).to_equal(c_expected).join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE, USAGE_ID')
      .exclude('USAGE_CONTEXT_ID');
   end user_identifiers;

   procedure plscope_identfiers_model_name is
      c_actual   sys_refcursor;
      c_expected sys_refcursor;
   begin
      -- populate actual
      open c_actual for
         select line, module_name
           from plscope_identifiers
          where object_type = 'PACKAGE BODY'
            and object_name = 'EXAMPLE'
            and line in (2, 11, 31);
            
      -- populate expected
      open c_expected for
         select 2 as line, null as module_name
           from dual
         union all
         select 11, 'TOP_LEVEL_PROCEDURE.SECOND_LEVEL_PROCEDURE.THIRD_LEVEL_PROCEDURE.FOURTH_LEVEL_FUNCTION.FIFTH_LEVEL_PROCEDURE'
           from dual
         union all
         select 31, 'FORWARD_DECLARED_PROCEDURE'
           from dual;
      
      -- assert
      ut.expect(c_actual).to_equal(c_expected).join_by('LINE');

   end plscope_identfiers_model_name;

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
           from sys.all_statements -- NOSONAR: avoid public synonym
          where owner = co_plsql_unit_owner 
          order by object_type, object_name, line, col, usage_id;

      -- assert
      ut.expect(c_actual).to_equal(c_expected).join_by('OBJECT_TYPE, OBJECT_NAME, LINE, COL, USAGE_ID')
      .exclude('USAGE_CONTEXT_ID, TEXT');
   end user_statements;

end test_plscope_identifiers;
/
