create or replace package body test_plscope_context is
   
   --
   -- test_set_attr
   --
   procedure test_set_attr is
      l_actual sys.session_context.value%type;
   begin
      plscope_context.set_attr(in_name => 'my_name', in_value => '1');
      l_actual := sys_context('PLSCOPE', 'my_name');
      ut.expect(l_actual).to_equal('1');
   end test_set_attr;
   
   --
   -- test_remove_attr
   --
   procedure test_remove_attr is
      l_actual sys.session_context.value%type;
   begin
      plscope_context.set_attr(in_name => 'my_name', in_value => '1');
      plscope_context.remove_attr('my_name');
      l_actual := sys_context('PLSCOPE', 'my_name');
      ut.expect(l_actual).to_(be_null);
   end test_remove_attr;

   --
   -- test_remove_all
   --
   procedure test_remove_all is
      l_actual integer;
   begin
      plscope_context.set_attr(in_name => 'my_name1', in_value => '1');
      plscope_context.set_attr(in_name => 'my_name2', in_value => '2');
      plscope_context.set_attr(in_name => 'my_name3', in_value => '3');
      plscope_context.set_attr(in_name => 'my_name4', in_value => '4');
      plscope_context.remove_all;
      select count(*)
        into l_actual
        from sys.session_context -- NOSONAR: avoid public synonym
       where namespace = 'PLSCOPE';
      ut.expect(l_actual).to_equal(0);
   end test_remove_all;

end test_plscope_context;
/
