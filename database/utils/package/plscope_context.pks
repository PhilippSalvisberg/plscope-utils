create or replace package plscope_context is
   /*
   * Copyright 2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
   *
   * Licensed under the Apache License, Version 2.0 (the "License");
   * you may not use this file except in compliance with the License.
   * You may obtain a copy of the License at
   *
   *     http://www.apache.org/licenses/LICENSE-2.0
   *
   * Unless required by applicable law or agreed to in writing, software
   * distributed under the License is distributed on an "AS IS" BASIS,
   * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   * See the License for the specific language governing permissions and
   * limitations under the License.
   */

   /** 
   * API to manage attributes of the context named PLSCOPE.
   *
   * @headcom
   */
   
   /**
   * Sets the value of a given attribute name.
   *
   * @param in_name name of the attribute
   * @param in_value value of the attribute
   */
   procedure set_attr(
      in_name  in varchar2,
      in_value in varchar2
   );

   /**
   * Removes an attribute from the context. 
   * Used to restore default behaviour for this attribute.
   *
   * @param in_name name of the attribute
   */
   procedure remove_attr(
      in_name in varchar2
   );

   /**
   * Removes all attributes from the context.
   * Used to restore default behaviour for all attributes.
   */
   procedure remove_all;

end plscope_context;
/
