create or replace package body test_dd_util is

   -- Forward decl.
   procedure wrap_dyn_exec(in_stmt in varchar2);

   --
   -- setup
   --
   procedure setup is
   begin
      wrap_dyn_exec(q'[
         create procedure p1 is
         begin
            null;
         end;
      ]');

      wrap_dyn_exec(q'[
         create view sample_vw1 as
            with
               cte(n, m2, m3) as (
                  select level, mod(level, 2), mod(level, 3) from dual connect by level <= 10
               )
            select *
              from cte
             pivot ( listagg(to_char(n), ', ') within group (order by n) as lst 
                     for m2 in (
                        0 as even,
                        1 as odd
                     )
                   )
      ]');

      wrap_dyn_exec('create synonym s1 for p1');
      wrap_dyn_exec('create synonym s2 for s1');
      wrap_dyn_exec('create synonym s3 for s2');
      
      wrap_dyn_exec('create public synonym weird_test_pubsyn1 for s3');
      wrap_dyn_exec('create synonym weird_test_pubsyn1 for "PUBLIC".weird_test_pubsyn1');
      wrap_dyn_exec('create public synonym weird_test_pubsyn2 for weird_test_pubsyn1');
      wrap_dyn_exec('create synonym weird_test_pubsyn2 for "PUBLIC".weird_test_pubsyn2');
      wrap_dyn_exec('create public synonym weird_test_pubsyn3 for weird_test_pubsyn2');
      wrap_dyn_exec('drop synonym weird_test_pubsyn2');  -- this invalidates "PUBLIC".weird_test_pubsyn3
      wrap_dyn_exec('drop synonym weird_test_pubsyn1');  -- this invalidates "PUBLIC".weird_test_pubsyn2
      wrap_dyn_exec('alter public synonym weird_test_pubsyn3 compile');  -- so let's revalidate both

      wrap_dyn_exec('create synonym syn_loop1 for p1');
      wrap_dyn_exec('create synonym syn_loop2 for syn_loop1');
      wrap_dyn_exec('create synonym syn_loop3 for syn_loop2');
      wrap_dyn_exec('create or replace synonym syn_loop1 for syn_loop3');
      
      wrap_dyn_exec('create table to_be_dropped_t1 (c1 number)');
      wrap_dyn_exec('create synonym syn_nonexistent for to_be_dropped_t1');
      wrap_dyn_exec('drop table to_be_dropped_t1 purge');

      -- issue 31: fix ORA-6550 that occurs from time to time while querying dba_synonyms
      ut_runner.rebuild_annotation_cache($$PLSQL_UNIT_OWNER);
   end setup;
   
   --
   -- teardown
   --
   procedure teardown is
   begin
      wrap_dyn_exec('drop synonym syn_nonexistent');
      wrap_dyn_exec('drop synonym syn_loop3');
      wrap_dyn_exec('drop synonym syn_loop2');
      wrap_dyn_exec('drop synonym syn_loop1');
      wrap_dyn_exec('drop public synonym weird_test_pubsyn3');
      wrap_dyn_exec('drop public synonym weird_test_pubsyn2');
      wrap_dyn_exec('drop public synonym weird_test_pubsyn1');
      wrap_dyn_exec('drop synonym s3');
      wrap_dyn_exec('drop synonym s2');
      wrap_dyn_exec('drop synonym s1');
      wrap_dyn_exec('drop view sample_vw1');
      wrap_dyn_exec('drop procedure p1');
   end teardown;

   --
   -- test_resolve_synonym
   --
   procedure test_resolve_synonym is
      o_input  obj_type;
      o_actual obj_type;
      l_current_schema user_users.username%type := sys_context('USERENV', 'CURRENT_SCHEMA');
   begin
      -- resolve
      o_input  := obj_type(null, null, 'S1');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_equal(l_current_schema);
      ut.expect(o_actual.object_type).to_equal('PROCEDURE');
      ut.expect(o_actual.object_name).to_equal('P1');
      
      -- resolve chain of synonyms
      o_input  := obj_type(null, null, 'S3');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_equal(l_current_schema);
      ut.expect(o_actual.object_type).to_equal('PROCEDURE');
      ut.expect(o_actual.object_name).to_equal('P1');
      
      -- resolve chain of synonyms, including public synonyms
      o_input  := obj_type(null, null, 'WEIRD_TEST_PUBSYN3');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_equal(l_current_schema);
      ut.expect(o_actual.object_type).to_equal('PROCEDURE');
      ut.expect(o_actual.object_name).to_equal('P1');

      -- shallow resolution (1st-level only)
      o_input  := obj_type(null, null, 'S3');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, 
         in_obj => o_input, in_in_depth => 0);
      ut.expect(o_actual.owner).to_equal(l_current_schema);
      ut.expect(o_actual.object_type).to_equal('SYNONYM');
      ut.expect(o_actual.object_name).to_equal('S2');
      
      -- failed resolve (synonym loop)
      o_input  := obj_type(null, null, 'SYN_LOOP3');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_(be_null);
      ut.expect(o_actual.object_type).to_(be_null);
      ut.expect(o_actual.object_name).to_(be_null);
      
      -- failed resolve (synonym of non-existent)
      o_input  := obj_type(null, null, 'SYN_NONEXISTENT');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_(be_null);
      ut.expect(o_actual.object_type).to_(be_null);
      ut.expect(o_actual.object_name).to_(be_null);
      
      -- no resolve
      o_input  := obj_type(null, null, 'P1');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_equal(l_current_schema);
      ut.expect(o_actual.object_type).to_equal('PROCEDURE');
      ut.expect(o_actual.object_name).to_equal('P1');
      
      -- unknown object
      o_input  := obj_type(null, null, 'X1');
      o_actual := dd_util.resolve_synonym(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_(be_null);
      ut.expect(o_actual.object_type).to_(be_null);
      ut.expect(o_actual.object_name).to_(be_null);
   end test_resolve_synonym;

   --
   -- test_get_object
   --
   procedure test_get_object is
      o_input  obj_type;
      o_actual obj_type;
      l_current_schema user_users.username%type := sys_context('USERENV', 'CURRENT_SCHEMA');
   begin
      -- synonym
      o_input  := obj_type(null, null, 'S1');
      o_actual := dd_util.get_object(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_(equal(l_current_schema));
      ut.expect(o_actual.object_type).to_(equal('SYNONYM'));
      ut.expect(o_actual.object_name).to_(equal('S1'));
      -- procedure
      o_input  := obj_type(null, null, 'P1');
      o_actual := dd_util.get_object(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_(equal(l_current_schema));
      ut.expect(o_actual.object_type).to_(equal('PROCEDURE'));
      ut.expect(o_actual.object_name).to_(equal('P1'));
      -- unknown object
      o_input  := obj_type(null, null, 'X1');
      o_actual := dd_util.get_object(in_parse_user => l_current_schema, in_obj => o_input);
      ut.expect(o_actual.owner).to_(be_null);
      ut.expect(o_actual.object_type).to_(be_null);
      ut.expect(o_actual.object_name).to_(be_null);
   end test_get_object;

   --
   -- test_get_objects
   --
   procedure test_get_objects is
      t_input    t_obj_type;
      t_actual   t_obj_type;
      t_expected t_obj_type;
      l_current_schema user_users.username%type := sys_context('USERENV', 'CURRENT_SCHEMA');
   begin
      t_input    := t_obj_type(
                       obj_type(null, null, 'P1'),
                       obj_type(null, null, 'S1'),
                       obj_type(null, null, 'XYZ'), -- not existing
                       obj_type(null, 'SYNONYM', 'S1') -- duplicate
                    );
      t_expected := t_obj_type(
                       obj_type(l_current_schema, 'PROCEDURE', 'P1'),
                       obj_type(l_current_schema, 'SYNONYM', 'S1')
                    );
      t_actual   := dd_util.get_objects(in_parse_user => l_current_schema, in_t_obj => t_input);
      ut.expect(t_actual.count).to_equal(2);
      ut.expect(sys.anydata.convertcollection(t_actual)).to_equal(sys.anydata.convertcollection(t_expected)).unordered;
   end test_get_objects;

   --
   -- test_get_column_id
   --
   procedure test_get_column_id is
      l_actual integer;
      l_current_schema user_users.username%type := sys_context('USERENV', 'CURRENT_SCHEMA');
   begin
      -- existing column
      l_actual := dd_util.get_column_id(
                     in_owner       => l_current_schema,
                     in_object_name => 'SAMPLE_VW1',
                     in_column_name => 'EVEN_LST'
                  );
      ut.expect(l_actual).to_equal(2);
      -- non-existing column
      l_actual := dd_util.get_column_id(
                     in_owner       => l_current_schema,
                     in_object_name => 'SAMPLE_VW1',
                     in_column_name => 'XYZ'
                  );
      ut.expect(l_actual).to_(be_null);
   end test_get_column_id;

   --
   -- test_get_view_source
   --
   procedure test_get_view_source is
      o_input  obj_type;
      l_actual clob;
      l_current_schema user_users.username%type := sys_context('USERENV', 'CURRENT_SCHEMA');
   begin
      -- fully qualified
      o_input  := obj_type(l_current_schema, 'VIEW', 'SAMPLE_VW1');
      l_actual := dd_util.get_view_source(o_input);
      ut.expect(l_actual).to_match(a_pattern => '^(WITH)(.+)$', a_modifiers => 'ni');
      -- not fully qualified
      o_input  := obj_type(null, 'VIEW', 'SAMPLE_VW1');
      l_actual := dd_util.get_view_source(o_input);
      ut.expect(l_actual).to_(be_null);
   end test_get_view_source;

   --
   -- wrap_dyn_exec: wrapper for execute immediate
   --
   procedure wrap_dyn_exec(in_stmt in varchar2) is
   begin
      execute immediate in_stmt;
   end wrap_dyn_exec;

end test_dd_util;
/
