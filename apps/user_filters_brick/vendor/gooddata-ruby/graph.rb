require 'graphviz'
require 'pry'
require 'rgl/adjacency'
require 'rgl/traversal'


definition = [
  ["a", [], type: :fact],
  ["b", ["a"], type: :fact],
  ["c", ["b"], type: :fact],
  ["d", ["b"], type: :attribute],
  ["e", ["c", "d"], type: :attribute],
  ["f", ["b"], type: :attribute],
  ["g", ["f"], type: :attribute],
  ["h", ["f"], type: :attribute],
  ["i", ["h"], type: :attribute]
  
]

nodes = definition.map { |r| r.first }
edges = definition.flat_map { |rule| rule[1].map { |d| [rule.first, d] } }
dg=RGL::DirectedAdjacencyGraph[*edges.flatten]

def add_node(g, rule)
  type = (rule[2] && rule[2][:type]) || :fact
  shape = case type
            when :fact
              'box'
            when :attribute
              'circle'
            end
  g.add_node( rule.first, shape: shape )
end

g = GraphViz.new( :G, :type => :digraph , :rankdir => 'BT')
definition.each { |rule| add_node(g, rule) }
edges.each { |a, b| g.add_edges(a, b) }

selected_node = nodes.sample

invisible_nodes = nodes - (dg.bfs_search_tree_from(selected_node).to_a + [selected_node])
invisible_nodes.each do |invisible_node|
  g.get_node(invisible_node).style = 'invis'
  g.each_edge.enum_for
    .select {|e| [e.node_one, e.node_two].include?(invisible_node)}
    .each {|edge| edge.style = 'invis'}
end




g.output( :png => "run_dag.png" )

# definition.map {|n| n.first}.sample(2).each do |invisible_node|
#   g.get_node(invisible_node).style = 'invis'
#   g.each_edge.enum_for
#     .select {|e| [e.node_one, e.node_two].include?(invisible_node)}
#     .each {|edge| edge.style = 'invis'}
# end
