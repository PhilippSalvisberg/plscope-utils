create or replace package body dd_util is

   --
   -- resolve_synonym
   --
   function resolve_synonym(
      in_parse_user in varchar2,
      in_obj        in obj_type
   ) return obj_type is
      o_obj obj_type;
      cursor c_lookup is
         select obj_type(
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           from sys.dba_synonyms s -- NOSONAR: avoid public synonym
           join sys.dba_objects o -- NOSONAR: avoid public synonym
             on o.owner = s.table_owner
            and o.object_name = s.table_name
          where s.owner = o_obj.owner
            and s.synonym_name = o_obj.object_name;
   begin
      o_obj := get_object(in_parse_user => in_parse_user, in_obj => in_obj);
      if o_obj.object_type = 'SYNONYM' then
         open c_lookup;
         fetch c_lookup into o_obj;
         close c_lookup;
      end if;
      return o_obj;
   end resolve_synonym;

   --
   -- get_object
   --
   function get_object(
      in_parse_user in varchar2,
      in_obj        in obj_type
   ) return obj_type is
      o_obj obj_type;
      cursor c_lookup is
         select obj_type(
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           from sys.dba_objects o -- NOSONAR: avoid public synonym
          where o.owner = coalesce(in_obj.owner, in_parse_user, 'PUBLIC')
            and o.object_name = in_obj.object_name
          order by case o.owner
                      when in_obj.owner then
                         1
                      when in_parse_user then
                         2
                      else
                         3
                   end,
                case o.object_type
                   when in_obj.object_type then
                      1
                   when 'SYNONYM' then
                      3
                   else
                      2
                end;
   begin
      open c_lookup;
      fetch c_lookup into o_obj;
      close c_lookup;
      return o_obj;
   end get_object;

   --
   -- get_objects
   --
   function get_objects(
      in_parse_user in varchar2,
      in_t_obj      in t_obj_type
   ) return t_obj_type is
      o_obj obj_type;
      t_obj t_obj_type := t_obj_type();
      i     pls_integer;
   begin
      if in_t_obj is not null and in_t_obj.count > 0 then
         -- in_t_obj could be sparse
         i := in_t_obj.first;
         <<input_objects>>
         while (i is not null)
         loop
            o_obj := get_object(
                        in_parse_user => in_parse_user,
                        in_obj        => in_t_obj(i)
                     );
            if o_obj.owner is not null then
               t_obj.extend;
               t_obj(t_obj.count) := o_obj;
            end if;
            i     := in_t_obj.next(i);
         end loop input_objects;
      end if;

      -- return final objects
      return type_util.dedup(in_t_obj => t_obj);
   end get_objects;

   --
   -- get_column_id
   --
   function get_column_id(
      in_owner       in varchar2,
      in_object_name in varchar2,
      in_column_name in varchar2
   ) return integer is
      l_column_id integer;
      cursor c_lookup is
         select column_id
           from sys.dba_tab_columns -- NOSONAR: avoid public synonym
          where owner = in_owner
            and table_name = in_object_name
            and column_name = in_column_name;
   begin
      open c_lookup;
      fetch c_lookup into l_column_id;
      close c_lookup;
      return l_column_id;
   end get_column_id;

   --
   -- get_view_source
   --
   function get_view_source(
      in_obj in obj_type
   ) return clob is
      l_source      long; -- NOSONAR, have to deal with LONG
      l_source_clob clob;
      cursor c_view_lookup is
         select text
           from sys.dba_views -- NOSONAR: avoid public synonym
          where owner = in_obj.owner
            and view_name = in_obj.object_name;
      cursor c_mview_lookup is
         select query
           from sys.dba_mviews -- NOSONAR: avoid public synonym
          where owner = in_obj.owner
            and mview_name = in_obj.object_name;
   begin
      case in_obj.object_type
         when 'VIEW' then
            open c_view_lookup;
            fetch c_view_lookup into l_source;
            close c_view_lookup;
            l_source_clob := l_source;
         when 'MATERIALIZED VIEW' then
            open c_mview_lookup;
            fetch c_mview_lookup into l_source;
            close c_mview_lookup;
            l_source_clob := l_source;
         else
            l_source := null;
      end case;
      return l_source_clob;
   end get_view_source;

end dd_util;
/
