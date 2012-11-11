# -*- coding: utf-8 -*-
# This module manages the serialisation and deserialisation of
# maps in the OpenRubyRMK. Storing maps is a two-step process:
# The first, primary action is to save all the maps themselves
# to their respective map files, which contain the information
# about fields, tilesets, etc. The second action is to store
# the information about the map hierarchy, or map tree, which
# is a bit tricky, because the underlying map format, TMX,
# doesn’t support hierarchical maps by itself. To circumvent
# this problem, we create a separate file called the <i>map
# tree file</i>; this is a simple XML file that describes the
# way the maps area layed out. It has the following structure:
#
#   <maps>
#     <map id="1"><!-- A root map -->
#       <map id="1-1"><!-- A child map -->
#         <map id="1-1-1"/><!-- A grandchild map -->
#       </map>
#       <map id="1-2"/><!-- Another child map -->
#     </map>
#     <map id="2"/><!-- Another root map -->
#   </maps>
#
# This may be nested arbitrarily deep. Regarding the map files
# itself, they use (as said before) the TMX format, which is
# described here[https://github.com/bjorn/tiled/wiki/TMX-Map-Format].
# Additionally, the filename is used to store the ID of a map, so
# you definitely don’t want to rename map files, or everything
# will explode.
#
# Use ::save_maps_tree to create both the tree file and save
# a given list of root maps, and use ::load_maps_tree to restore
# the whole thing.
module OpenRubyRMK::Backend::MapStorage

  class << self

    # Reads in a map tree file and map files and reconstructs
    # the Map instances they belonged to. In short, it takes
    # the results of ::save_maps_tree and turns them into Ruby
    # objects again.
    # == Parameters
    # [maps_dir]
    #   The directory where to find the maps referenced in the
    #   map tree file.
    # [maptree_file]
    #   The path to the file containing the map tree.
    # == Return value
    # All found root maps as an array of Map instances, all
    # fully populated with children attached.
    def load_maps_tree(maps_dir, maptree_file)
      xml = Nokogiri::XML(File.open(maptree_file)) # autoclosed by Nokogiri
      root_maps = []
      xml.root.xpath("map").each do |map|
        root_maps << read_map_from_tree(maps_dir, map)
      end

      root_maps
    end

    # Builds up the map tree file and writes it out to disk,
    # then saves all map into the indicated maps directory.
    # The result can be read back in with ::load_maps_tree.
    # == Parameters
    # [maps_dir]
    #   The directory where to save the map files in.
    # [maptree_file]
    #   The path to the file where to save the the map tree
    #   into.
    # [*root_maps]
    #   All maps you want to be affected by this method, which
    #   normally are all root maps of your project.
    # == Raises
    # [DuplicateMapID]
    #   Somewhere on the trees on your +root_maps+ an ID
    #   occurs multiple times. Check the exception object
    #   to find out what ID it exactly is. No files have
    #   been modified/created if you get this exception,
    #   so it is safe to resolve the problem and then try
    #   saving again.
    def save_maps_tree(maps_dir, maptree_file, *root_maps)
      maps_dir     = Pathname.new(maps_dir)
      maptree_file = Pathname.new(maptree_file)

      # Ensure we have no duplicate IDs; this would corrupt
      # the maps hierarchy file and at least one map file
      # would be lost due to overwriting.
      check_map_ids!(*root_maps)

      # 0. Wipe out the entire maps folder, so we effectively
      # delete map files whose maps have been unmounted from
      # the map tree.
      maps_dir.each_child{|path| path.delete}

      # 1. Create the maptree file
      # See the module docs for the exact format
      maptree_file.open("w") do |file|
        b = Nokogiri::XML::Builder.new do |xml|
          xml.maps do |maptree|
            root_maps.each{|map| add_map_to_tree(map, maptree)}
          end #</maptee>
        end #XML::Builder.new

        file.write(b.to_xml)
      end #open

      # 2. Save the actual maps
      root_maps.each do |root_map|
        root_map.traverse(true){|map| map.save(maps_dir)}
      end
    end #save_tree

    # Iterates through all +root_maps+ and their children
    # and checks whether all maps in the trees have globally
    # unique IDs. It not, raise an exception.
    # == Parameters
    # [*root_maps]
    #   The root maps you want to start traversing at.
    # == Raises
    # [DuplicateMapID]
    #   When a duplicate map ID is found somewhere on the trees.
    def check_map_ids!(*root_maps)
      seen_ids = []
      root_maps.each do |root_map|
        root_map.traverse(true) do |map|
          raise(OpenRubyRMK::Backend::Errors::DuplicateMapID.new(map.id)) if seen_ids.include?(map.id)
          seen_ids << map.id
        end
      end
    end

    private

    # Recursive helper method for building up the map tree.
    # Adds the +map+ to the given XML +node+, then repeates
    # this process for each child map of +map+, handing the
    # freshly created node as the +node+ parameter.
    def add_map_to_tree(map, node)
      node.map(:id => map.id) do |subnode|
        map.children.each{|child_map| add_map_to_tree(child_map, subnode)}
      end
    end

    # Recursive helper methods for reconstructing the maps
    # from the map tree file. First constructs the Map object
    # corresponding to +map_node+, attaching it the given
    # +parent+, if any, via Map#parent=, then repeats the
    # process for all child nodes, but now passing the
    # freshly constructed map object as the +parent+ parameter.
    # Returns the Map object corresponding to +map_node+, children
    # already attached (if any).
    def read_map_from_tree(maps_dir, map_node, parent = nil)
      # Reconstruct this map from the XML
      target = maps_dir + OpenRubyRMK::Backend::Map.format_filename(map_node["id"].to_i)
      map = OpenRubyRMK::Backend::Map.from_file(target)
      map.parent = parent # nil = root map

      # Repeat the process for all child maps, but now use
      # our freshly reconstructed Map object as the parent
      map_node.xpath("map").each do |submap_node|
        read_map_from_tree(maps_dir, submap_node, map)
      end

      map
    end

  end #class << self

end
