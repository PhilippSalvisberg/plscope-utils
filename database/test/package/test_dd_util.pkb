create or replace package body test_dd_util is

   --
   -- setup
   --
   procedure setup is
   begin
      execute immediate q'[ -- NOSONAR: G-6010
         create or replace procedure p1 is
         begin
            null;
         end;
      ]';
      execute immediate 'create or replace synonym s1 for p1'; -- NOSONAR: G-6010
      -- issue 31: fix ORA-6550 that occurs from time to time while querying dba_synonyms
      ut_runner.rebuild_annotation_cache(user);
   end setup;
   
   --
   -- teardown
   --
   procedure teardown is
   begin
      execute immediate 'drop synonym s1';   -- NOSONAR: G-6010
      execute immediate 'drop procedure P1'; -- NOSONAR: G-6010
   end teardown;

   --
   -- test_resolve_synonym
   --
   procedure test_resolve_synonym is
      l_input  obj_type;
      l_actual obj_type;
   begin
      -- resolve
      l_input  := obj_type(null, null, 'S1');
      l_actual := dd_util.resolve_synonym(in_parse_user => user, in_obj => l_input);
      ut.expect(l_actual.owner).to_equal(user);
      ut.expect(l_actual.object_type).to_equal('PROCEDURE');
      ut.expect(l_actual.object_name).to_equal('P1');
      -- no resolve
      l_input  := obj_type(null, null, 'P1');
      l_actual := dd_util.resolve_synonym(in_parse_user => user, in_obj => l_input);
      ut.expect(l_actual.owner).to_equal(user);
      ut.expect(l_actual.object_type).to_equal('PROCEDURE');
      ut.expect(l_actual.object_name).to_equal('P1');
      -- unknown object
      l_input  := obj_type(null, null, 'X1');
      l_actual := dd_util.resolve_synonym(in_parse_user => user, in_obj => l_input);
      ut.expect(l_actual.owner).to_(be_null);
      ut.expect(l_actual.object_type).to_(be_null);
      ut.expect(l_actual.object_name).to_(be_null);
   end test_resolve_synonym;

   --
   -- test_get_object
   --
   procedure test_get_object is
      l_input  obj_type;
      l_actual obj_type;
   begin
      -- synonym
      l_input  := obj_type(null, null, 'S1');
      l_actual := dd_util.get_object(in_parse_user => user, in_obj => l_input);
      ut.expect(l_actual.owner).to_(equal(user));
      ut.expect(l_actual.object_type).to_(equal('SYNONYM'));
      ut.expect(l_actual.object_name).to_(equal('S1'));
      -- procedure
      l_input  := obj_type(null, null, 'P1');
      l_actual := dd_util.get_object(in_parse_user => user, in_obj => l_input);
      ut.expect(l_actual.owner).to_(equal(user));
      ut.expect(l_actual.object_type).to_(equal('PROCEDURE'));
      ut.expect(l_actual.object_name).to_(equal('P1'));
      -- unknown object
      l_input  := obj_type(null, null, 'X1');
      l_actual := dd_util.get_object(in_parse_user => user, in_obj => l_input);
      ut.expect(l_actual.owner).to_(be_null);
      ut.expect(l_actual.object_type).to_(be_null);
      ut.expect(l_actual.object_name).to_(be_null);
   end test_get_object;

   --
   -- test_get_objects
   --
   procedure test_get_objects is
      l_input    t_obj_type;
      l_actual   t_obj_type;
      l_expected t_obj_type;
   begin
      l_input    := t_obj_type(
                       obj_type(null, null, 'P1'),
                       obj_type(null, null, 'S1'),
                       obj_type(null, null, 'XYZ'), -- not existing
                       obj_type(null, 'SYNONYM', 'S1') -- duplicate
                    );
      l_expected := t_obj_type(
                       obj_type(user, 'PROCEDURE', 'P1'),
                       obj_type(user, 'SYNONYM', 'S1')
                    );
      l_actual   := dd_util.get_objects(in_parse_user => user, in_t_obj => l_input);
      ut.expect(l_actual.count).to_equal(2);
      ut.expect(sys.anydata.convertcollection(l_actual)).to_equal(sys.anydata.convertcollection(l_expected)).unordered;
   end test_get_objects;

   --
   -- test_get_column_id
   --
   procedure test_get_column_id is
      l_actual integer;
   begin
      -- existing column
      l_actual := dd_util.get_column_id(
                     in_owner       => user,
                     in_object_name => 'PLSCOPE_IDENTIFIERS',
                     in_column_name => 'LINE'
                  );
      ut.expect(l_actual).to_equal(4);
      -- non-existing column
      l_actual := dd_util.get_column_id(
                     in_owner       => user,
                     in_object_name => 'PLSCOPE_IDENTIFIERS',
                     in_column_name => 'XYZ'
                  );
      ut.expect(l_actual).to_(be_null);
   end test_get_column_id;

   --
   -- test_get_view_source
   --
   procedure test_get_view_source is
      l_input  obj_type;
      l_actual clob;
   begin
      -- fully qualified
      l_input  := obj_type(user, 'VIEW', 'PLSCOPE_IDENTIFIERS');
      l_actual := dd_util.get_view_source(l_input);
      ut.expect(l_actual).to_match(a_pattern => '^(WITH)(.+)$', a_modifiers => 'ni');
      -- not fully qualified
      l_input  := obj_type(null, 'VIEW', 'PLSCOPE_IDENTIFIERS');
      l_actual := dd_util.get_view_source(l_input);
      ut.expect(l_actual).to_(be_null);
   end test_get_view_source;

end test_dd_util;
/
