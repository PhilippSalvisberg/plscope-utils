CREATE OR REPLACE PACKAGE BODY test_dd_util IS

   --
   -- setup
   --
   PROCEDURE setup IS
   BEGIN
      EXECUTE IMMEDIATE q'[
         CREATE OR REPLACE PROCEDURE p1 IS 
         BEGIN 
            NULL; 
         END;
      ]';
      EXECUTE IMMEDIATE 'CREATE OR REPLACE SYNONYM s1 FOR p1';
      -- issue 31: fix ORA-6550 that occurs from time to time while querying dba_synonyms
      ut_runner.rebuild_annotation_cache(user);
   END setup;
   
   --
   -- teardown
   --
   PROCEDURE teardown IS
   BEGIN
      EXECUTE IMMEDIATE 'DROP SYNONYM s1';
      EXECUTE IMMEDIATE 'DROP PROCEDURE p1';
   END teardown;

   --
   -- test_resolve_synonym
   --
   PROCEDURE test_resolve_synonym IS
      l_input    obj_type;
      l_actual   obj_type;
   BEGIN
      -- resolve
      l_input := obj_type(NULL, NULL, 'S1');
      l_actual := dd_util.resolve_synonym(USER, l_input);
      ut.expect(l_actual.owner).to_equal(USER);
      ut.expect(l_actual.object_type).to_equal('PROCEDURE');
      ut.expect(l_actual.object_name).to_equal('P1');
      -- no resolve
      l_input := obj_type(NULL, NULL, 'P1');
      l_actual := dd_util.resolve_synonym(USER, l_input);
      ut.expect(l_actual.owner).to_equal(USER);
      ut.expect(l_actual.object_type).to_equal('PROCEDURE');
      ut.expect(l_actual.object_name).to_equal('P1');
      -- unknown object
      l_input := obj_type(NULL, NULL, 'X1');
      l_actual := dd_util.resolve_synonym(USER, l_input);
      ut.expect(l_actual.owner).to_(be_null);
      ut.expect(l_actual.object_type).to_(be_null);
      ut.expect(l_actual.object_name).to_(be_null);      
   END test_resolve_synonym;

   --
   -- test_get_object
   --
   PROCEDURE test_get_object IS
      l_input  obj_type;
      l_actual obj_type;
   BEGIN
      -- synonym
      l_input := obj_type(NULL, NULL, 'S1');
      l_actual := dd_util.get_object(USER, l_input);
      ut.expect(l_actual.owner).to_(equal(USER));
      ut.expect(l_actual.object_type).to_(equal('SYNONYM'));
      ut.expect(l_actual.object_name).to_(equal('S1'));
      -- procedure
      l_input := obj_type(NULL, NULL, 'P1');
      l_actual := dd_util.get_object(USER, l_input);
      ut.expect(l_actual.owner).to_(equal(USER));
      ut.expect(l_actual.object_type).to_(equal('PROCEDURE'));
      ut.expect(l_actual.object_name).to_(equal('P1'));
      -- unknown object
      l_input := obj_type(NULL, NULL, 'X1');
      l_actual := dd_util.get_object(USER, l_input);
      ut.expect(l_actual.owner).to_(be_null);
      ut.expect(l_actual.object_type).to_(be_null);
      ut.expect(l_actual.object_name).to_(be_null);      
   END test_get_object;

   --
   -- test_get_objects
   --
   PROCEDURE test_get_objects IS
      l_input    t_obj_type;
      l_actual   t_obj_type;
      l_expected t_obj_type;
   BEGIN
      l_input := t_obj_type(
                    obj_type(NULL, NULL, 'P1'),
                    obj_type(NULL, NULL, 'S1'),
                    obj_type(NULL, NULL, 'XYZ'), -- not existing
                    obj_type(NULL, 'SYNONYM', 'S1') -- duplicate
                 );
      l_expected := t_obj_type(
                    obj_type(USER, 'PROCEDURE', 'P1'),
                    obj_type(USER, 'SYNONYM', 'S1')
                 );
      l_actual := dd_util.get_objects(USER, l_input);
      ut.expect(l_actual.count).to_equal(2);
      ut.expect(anydata.convertCollection(l_actual))
         .to_equal(anydata.convertCollection(l_expected)).unordered;
   END test_get_objects;

   --
   -- test_get_column_id
   --
   PROCEDURE test_get_column_id IS
      l_actual INTEGER;
   BEGIN
      -- existing column
      l_actual := dd_util.get_column_id(USER, 'PLSCOPE_IDENTIFIERS', 'LINE');
      ut.expect(l_actual).to_equal(4);
      -- non-existing column
      l_actual := dd_util.get_column_id(USER, 'PLSCOPE_IDENTIFIERS', 'XYZ');
      ut.expect(l_actual).to_(be_null);
   END test_get_column_id;

   --
   -- test_get_view_source
   --
   PROCEDURE test_get_view_source IS
      l_input  obj_type;
      l_actual CLOB;
   BEGIN
      -- fully qualified
      l_input := obj_type(USER, 'VIEW', 'PLSCOPE_IDENTIFIERS');
      l_actual := dd_util.get_view_source(l_input);
      ut.expect(l_actual).to_match('^(WITH)(.+)$', 'n');
      -- not fully qualified
      l_input := obj_type(NULL, 'VIEW', 'PLSCOPE_IDENTIFIERS');
      l_actual := dd_util.get_view_source(l_input);
      ut.expect(l_actual).to_(be_null);
   END test_get_view_source;
         
END test_dd_util;
/
