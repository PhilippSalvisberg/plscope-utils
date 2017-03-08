declare function local:analyze-col($col as element()) as element()* {
   let $tableAlias := $col/ancestor::QUERY[1]/FROM/FROM_ITEM//TABLE_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                          and text() = $col/TABLE_ALIAS/text()]
   let $tableAliasTable := if ($tableAlias) then (
                              $tableAlias/preceding::TABLE[1]
                           ) else (
                           )
   let $queryAlias := $col/ancestor::QUERY[1]/FROM/FROM_ITEM//QUERY_ALIAS[local-name(..) != 'COLUMN_REF' 
                                                                          and text() = $col/TABLE_ALIAS/text()]
   let $column := $col/COLUMN
   let $ret := if ($queryAlias) then (
                  for $rcol in $col/ancestor::QUERY/WITH/WITH_ITEM[QUERY_ALIAS/text() = $queryAlias/text()]
                               //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                              or COLUMN/text() = $column/text()]
                  let $rret := if ($rcol) then (
                                  local:analyze-col($rcol)
                               ) else (
                               )
                  return $rret
               ) else (
                  let $tables := if ($tableAliasTable) then (
                                    $tableAliasTable
                                 ) else (
                                    for $tab in $col/ancestor::QUERY[1]/FROM/FROM_ITEM//*[self::TABLE or self::QUERY_ALIAS]
                                    return $tab
                                 )
                  for $tab in $tables
                  return
                     typeswitch($tab)
                     case element(QUERY_ALIAS)
                        return
                           let $rcol := $col/ancestor::QUERY/WITH/WITH_ITEM[QUERY_ALIAS/text() = $tab/text()]
                                        //SELECT_LIST_ITEM//COLUMN_REF[ancestor::SELECT_LIST_ITEM/COLUMN_ALIAS/text() = $column/text() 
                                                                       or COLUMN/text() = $column/text()]
                           let $rret := if ($rcol) then (
                                           for $c in $rcol 
                                           return local:analyze-col($c) 
                                        ) else (
                                        )
                           return $rret
                     default
                        return
                           <column>
                              <schemaName>
                                 {$tab/../SCHEMA/text()}
                              </schemaName>
                              <tableName>
                                 {$tab/text()}
                              </tableName>
                              <columnName>
                                 {$column/text()}
                              </columnName>
                           </column>
               )
   return $ret
};

for $col in //SELECT/SELECT_LIST/SELECT_LIST_ITEM[not(ancestor::SELECT_LIST_ITEM)][1]//COLUMN_REF
let $res := local:analyze-col($col)
return $res
(: Stylus Studio meta-information - (c) 2004-2009. Progress Software Corporation. All rights reserved.

<metaInformation>
   <scenarios>
      <scenario default="no" name="source_view" userelativepaths="yes" externalpreview="no" useresolver="yes" url="source_view.xml" outputurl="" processortype="saxon" tcpport="0" profilemode="0" profiledepth="" profilelength="" urlprofilexml=""
                commandline="" additionalpath="" additionalclasspath="" postprocessortype="none" postprocesscommandline="" postprocessadditionalpath="" postprocessgeneratedext="" host="" port="0" user="" password="" validateoutput="no" validator="internal"
                customvalidator="">
         <advancedProperties name="bSchemaAware" value="true"/>
         <advancedProperties name="CollectionURIResolver" value=""/>
         <advancedProperties name="ModuleURIResolver" value=""/>
         <advancedProperties name="schemaCache" value="||"/>
         <advancedProperties name="bXml11" value="false"/>
         <advancedProperties name="bUseDTD" value="false"/>
         <advancedProperties name="bWarnings" value="true"/>
         <advancedProperties name="iWhitespace" value="0"/>
         <advancedProperties name="DocumentURIResolver" value=""/>
         <advancedProperties name="bTinyTree" value="true"/>
         <advancedProperties name="bGenerateByteCode" value="true"/>
         <advancedProperties name="iValidation" value="0"/>
         <advancedProperties name="bExtensions" value="true"/>
         <advancedProperties name="xQueryVersion" value="1.0"/>
      </scenario>
      <scenario default="no" name="plscope_tab_usage" userelativepaths="yes" externalpreview="no" useresolver="yes" url="plscope_tab_usage.xml" outputurl="" processortype="saxon" tcpport="0" profilemode="0" profiledepth="" profilelength="" urlprofilexml=""
                commandline="" additionalpath="" additionalclasspath="" postprocessortype="none" postprocesscommandline="" postprocessadditionalpath="" postprocessgeneratedext="" host="" port="0" user="" password="" validateoutput="no" validator="internal"
                customvalidator="">
         <advancedProperties name="bSchemaAware" value="true"/>
         <advancedProperties name="CollectionURIResolver" value=""/>
         <advancedProperties name="ModuleURIResolver" value=""/>
         <advancedProperties name="schemaCache" value="||"/>
         <advancedProperties name="bXml11" value="false"/>
         <advancedProperties name="bUseDTD" value="false"/>
         <advancedProperties name="bWarnings" value="true"/>
         <advancedProperties name="iWhitespace" value="0"/>
         <advancedProperties name="DocumentURIResolver" value=""/>
         <advancedProperties name="bTinyTree" value="true"/>
         <advancedProperties name="bGenerateByteCode" value="true"/>
         <advancedProperties name="iValidation" value="0"/>
         <advancedProperties name="bExtensions" value="true"/>
         <advancedProperties name="xQueryVersion" value="1.0"/>
      </scenario>
      <scenario default="no" name="dba_tab_col_v$" userelativepaths="yes" externalpreview="no" useresolver="yes" url="dba_tab_cols_v$.xml" outputurl="" processortype="saxon" tcpport="0" profilemode="0" profiledepth="" profilelength="" urlprofilexml=""
                commandline="" additionalpath="" additionalclasspath="" postprocessortype="none" postprocesscommandline="" postprocessadditionalpath="" postprocessgeneratedext="" host="" port="0" user="" password="" validateoutput="no" validator="internal"
                customvalidator="">
         <advancedProperties name="bSchemaAware" value="true"/>
         <advancedProperties name="CollectionURIResolver" value=""/>
         <advancedProperties name="ModuleURIResolver" value=""/>
         <advancedProperties name="schemaCache" value="||"/>
         <advancedProperties name="bXml11" value="false"/>
         <advancedProperties name="bUseDTD" value="false"/>
         <advancedProperties name="bWarnings" value="true"/>
         <advancedProperties name="iWhitespace" value="0"/>
         <advancedProperties name="DocumentURIResolver" value=""/>
         <advancedProperties name="bTinyTree" value="true"/>
         <advancedProperties name="bGenerateByteCode" value="true"/>
         <advancedProperties name="iValidation" value="0"/>
         <advancedProperties name="bExtensions" value="true"/>
         <advancedProperties name="xQueryVersion" value="1.0"/>
      </scenario>
      <scenario default="yes" name="dba_objects" userelativepaths="yes" externalpreview="no" useresolver="yes" url="dba_objects.xml" outputurl="" processortype="saxon" tcpport="0" profilemode="0" profiledepth="" profilelength="" urlprofilexml=""
                commandline="" additionalpath="" additionalclasspath="" postprocessortype="none" postprocesscommandline="" postprocessadditionalpath="" postprocessgeneratedext="" host="" port="0" user="" password="" validateoutput="no" validator="internal"
                customvalidator="">
         <advancedProperties name="bSchemaAware" value="true"/>
         <advancedProperties name="CollectionURIResolver" value=""/>
         <advancedProperties name="ModuleURIResolver" value=""/>
         <advancedProperties name="schemaCache" value="||"/>
         <advancedProperties name="bXml11" value="false"/>
         <advancedProperties name="bUseDTD" value="false"/>
         <advancedProperties name="bWarnings" value="true"/>
         <advancedProperties name="iWhitespace" value="0"/>
         <advancedProperties name="DocumentURIResolver" value=""/>
         <advancedProperties name="bTinyTree" value="true"/>
         <advancedProperties name="bGenerateByteCode" value="true"/>
         <advancedProperties name="iValidation" value="0"/>
         <advancedProperties name="bExtensions" value="true"/>
         <advancedProperties name="xQueryVersion" value="1.0"/>
      </scenario>
   </scenarios>
   <MapperMetaTag>
      <MapperInfo srcSchemaPathIsRelative="yes" srcSchemaInterpretAsXML="no" destSchemaPath="" destSchemaRoot="" destSchemaPathIsRelative="yes" destSchemaInterpretAsXML="no">
         <SourceSchema srcSchemaPath="plscope_tab_usage.xml" srcSchemaRoot="QUERY" AssociatedInstance="" loaderFunction="document" loaderFunctionUsesURI="no"/>
      </MapperInfo>
      <MapperBlockPosition>
         <template name="xquery_body">
            <block path="flwr" x="460" y="18"/>
         </template>
      </MapperBlockPosition>
      <TemplateContext></TemplateContext>
      <MapperFilter side="source"></MapperFilter>
   </MapperMetaTag>
</metaInformation>
:)