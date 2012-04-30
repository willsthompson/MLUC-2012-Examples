(:
LICENSE
=================================================================================
Copyright (c) 2012 Will Thompson, Jones McClure Publishing. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use 
this file except in compliance with the License. You may obtain a copy of the 
License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed 
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
CONDITIONS OF ANY KIND, either express or implied. See the License for the 
specific language governing permissions and limitations under the License.
The use of the Apache License does not indicate that this project is affiliated
with the Apache Software Foundation.
----------------------------------------------------------------------------------
:)

xquery version "1.0-ml";
module namespace exprun = "http://jonesmcclure.com/xq/exprun";

import module namespace search = "http://marklogic.com/appservices/search" 
    at "/MarkLogic/appservices/search/search.xqy";
import module namespace thsr = "http://marklogic.com/xdmp/thesaurus" 
    at "/MarkLogic/thesaurus.xqy";


declare function exprun:resolve-runs(
    $q as item()
) as item()*
{
    typeswitch($q)
        case element(run) return (
            for $n in cts:tokenize($q/text())[. instance of cts:word]
            return
                element cts:word-query{
                    $q/@*,
                    element cts:text {$n},
                    $q/cts:option
                },
                $q/element() except $q/cts:option
            )
        case text() return $q
        default return
            element {node-name($q)}{
                $q/namespace::*,
                $q/@*,
                local:resolve-runs($q/node())
            }
};

declare function exprun:thsr-expand-runs(
    $q as item(),     (: query with runs :)
    $q-thsr as item() (: thesaurus terms :)
) as item()
{
    typeswitch($q)    
        case element(run) return
            cts:highlight($q, $q-thsr,
                if (count($cts:queries) gt 1)
                then xdmp:set($cts:action, "continue") (: ignore matches within matches :)
                else          
                    let $options := $q/cts:option/string()
                    let $term := document{$cts:queries}/cts:word-query/cts:text/string()
                    let $toks := cts:tokenize($term)[. instance of cts:word]
                    let $entries := thsr:lookup("jmp-thesaurus.xml",$term)                    
                    return
                        cts:or-query((
                            (: matching term/phrase :) 
                            cts:and-query( 
                                for $t in $toks 
                                return cts:word-query($t,$options) 
                            ),
                            (: synonyms :) 
                            for $term in $entries/thsr:synonym/thsr:term
                            return cts:word-query($term/string(), $options)
                        ))) 
        case text() return $q
        default return
            element {node-name($q)}{
                $q/namespace::*,
                $q/@*,
                local:thsr-expand-runs($q/node(), $q-thsr)
            }
};

declare function exprun:create-runs(
    $q as item()
) as item()?
{
    typeswitch($q)
        case element(cts:word-query) return
            if (contains($q/cts:text," ") or not($q/parent::cts:and-query)) 
            then $q (: ignore phrases and non-and-query children :)
            else 
                if ($q/preceding-sibling::node()[1]
                      [self::cts:word-query][not(contains(cts:text," "))]) 
                then () (: delete subsequent nonphrase word-query :)
                else 
                    element run {(
                        $q/@*,
                        $q/element() except $q/cts:text,
                        $q/cts:text/string(),
                        let $stop := 
                          $q/following-sibling::node()
                            [not(self::cts:word-query[not(contains(cts:text," "))])][1]
                        return 
                           if (empty($stop)) 
                           then $q/following-sibling::node()/cts:text/string()
                           else $q/following-sibling::node()[. << $stop]/cts:text/string()
                    )}
        case text() return $q
        default return
            element {node-name($q)}{
                $q/namespace::*,
                $q/@*,
                local:create-runs($q/node())
            }
};


declare function exprun:unnest-ands(
    $q as item()
) as item()+
{  
    typeswitch($q)
        case element(cts:and-query) return
            if ($q/parent::cts:and-query)
            then
                (: implicit - unwrap :)
                local:unnest-ands($q/node())  
            else
                (: not implicit - keep :)
                (:cts:and-query(
                  cts:query(local:unnest-ands($q/node()))
                ):)
                element {node-name($q)}{                
                    $q/namespace::*,
                    $q/@*,
                    local:unnest-ands($q/node()) 
                }
        case text() return $q
        default return 
            element {node-name($q)}{                
                $q/namespace::*,
                $q/@*,
                local:unnest-ands($q/node()) 
            }
};

(: query-expand-runs.xqm :)
