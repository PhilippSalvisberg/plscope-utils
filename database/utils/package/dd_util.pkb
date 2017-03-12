CREATE OR REPLACE PACKAGE BODY dd_util IS

   --
   -- resolve_synonym
   --
   FUNCTION resolve_synonym (
      in_parse_user IN VARCHAR2,
      in_obj        IN obj_type
   ) return obj_type IS
      r_obj obj_type;
      CURSOR c_lookup IS
         SELECT obj_type (
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           FROM dba_synonyms s
           JOIN dba_objects o
             ON o.owner = s.table_owner
                AND o.object_name = s.table_name
          WHERE s.owner = r_obj.owner
            AND s.synonym_name = r_obj.object_name;
   BEGIN
      r_obj := get_object(in_parse_user => in_parse_user, in_obj => in_obj);
      IF r_obj.object_type = 'SYNONYM' THEN
         OPEN c_lookup;
         FETCH c_lookup INTO r_obj;
         CLOSE c_lookup;
      END IF;
      RETURN r_obj;
   END resolve_synonym;

   --
   -- get_object
   --
   FUNCTION get_object(
      in_parse_user IN VARCHAR2,
      in_obj        IN obj_type
   ) RETURN obj_type IS
      r_obj obj_type;
      CURSOR c_lookup IS
         SELECT obj_type (
                   owner       => o.owner,
                   object_type => o.object_type,
                   object_name => o.object_name
                )
           FROM dba_objects o
          WHERE o.owner = coalesce(in_obj.owner, in_parse_user, 'PUBLIC')
            AND o.object_name = in_obj.object_name
          ORDER BY CASE o.owner
                      WHEN in_obj.owner THEN
                         1
                      WHEN in_parse_user THEN
                         2
                      ELSE 
                         3
                   END,
                   CASE o.object_type
                      WHEN in_obj.object_type THEN
                         1
                      WHEN 'SYNONYM' THEN
                         3
                      ELSE
                         2
                   END;
   BEGIN
      OPEN c_lookup;
      FETCH c_lookup INTO r_obj;
      CLOSE c_lookup;
      RETURN r_obj;
   END get_object;

   --
   -- get_objects
   --
   FUNCTION get_objects(
      in_parse_user IN VARCHAR2, 
      in_t_obj      IN t_obj_type
   ) RETURN t_obj_type IS
      r_obj    obj_type;
      t_obj    t_obj_type := t_obj_type();
   BEGIN
      IF in_t_obj IS NOT NULL AND in_t_obj.COUNT > 0 THEN
         <<input_objects>>
         FOR i IN 1 .. in_t_obj.count LOOP
            r_obj := get_object(
                        in_parse_user => in_parse_user, 
                        in_obj        => in_t_obj(i)
                     );
            IF r_obj.owner IS NOT NULL THEN
               t_obj.extend;
               t_obj(t_obj.count) := r_obj;
            END IF;
         END LOOP input_objects;
      END IF;

      -- return final objects
      RETURN type_util.dedup(in_t_obj => t_obj);
   END get_objects;

   --
   -- get_column_id
   --
   FUNCTION get_column_id(
      in_owner       IN VARCHAR2,
      in_object_name IN VARCHAR2,
      in_column_name IN VARCHAR2
   ) RETURN INTEGER IS
      l_column_id INTEGER;
      CURSOR c_lookup IS
         SELECT column_id
           FROM dba_tab_columns
          WHERE owner       = in_owner
            AND table_name  = in_object_name
            AND column_name = in_column_name;   
   BEGIN
      OPEN c_lookup;
      FETCH c_lookup into l_column_id;
      CLOSE c_lookup;
      RETURN l_column_id;   
   END get_column_id;

   --
   -- get_view_source
   --
   FUNCTION get_view_source(
      in_obj IN obj_type
   ) RETURN CLOB IS
     l_source      LONG; -- NOSONAR, have to deal with LONG
     l_source_clob CLOB;
     CURSOR c_lookup IS
        SELECT text
          FROM dba_views
         WHERE owner     = in_obj.owner
           AND view_name = in_obj.object_name;
   BEGIN
     -- TODO: handle materialized views
     IF in_obj.object_type = 'VIEW' THEN
        OPEN c_lookup;
        FETCH c_lookup INTO l_source;
        CLOSE c_lookup;
        l_source_clob := l_source;
     END IF;
     RETURN l_source_clob;
   END get_view_source;
      
END dd_util;
/
