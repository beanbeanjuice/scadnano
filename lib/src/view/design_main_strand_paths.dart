import 'dart:html';
import 'dart:math';

import 'package:over_react/over_react.dart';
import 'package:built_collection/built_collection.dart';
import 'package:scadnano/src/state/substrand.dart';

import '../state/modification_type.dart';
import 'design_main_strand.dart';
import 'transform_by_helix_group.dart';
import '../state/group.dart';
import '../state/context_menu.dart';
import '../state/dna_end.dart';
import '../state/geometry.dart';
import '../state/helix.dart';
import '../state/design.dart';
import '../state/strand.dart';
import '../state/domain.dart';
import '../state/crossover.dart';
import '../state/loopout.dart';
import '../state/extension.dart';
import '../state/address.dart';
import '../util.dart' as util;
import 'design_main_strand_dna_end.dart';
import 'design_main_strand_domain.dart';
import 'design_main_strand_loopout.dart';
import 'design_main_strand_extension.dart';
import 'design_main_strand_crossover.dart';
import 'pure_component.dart';

part 'design_main_strand_paths.over_react.g.dart';

UiFactory<DesignMainStrandPathsProps> DesignMainStrandPaths = _$DesignMainStrandPaths;

mixin DesignMainStrandPathsProps on UiProps implements TransformByHelixGroupPropsMixin {
  late Strand strand;

  BuiltSet<int>? side_selected_helix_idxs; // null if only_display_selected_helices is false
  late bool only_display_selected_helices;

  late BuiltSet<DNAEnd> selected_ends_in_strand;
  late BuiltSet<Crossover> selected_crossovers_in_strand;
  late BuiltSet<Loopout> selected_loopouts_in_strand;
  late BuiltSet<Extension> selected_extensions_in_strand;
  late BuiltSet<Domain> selected_domains_in_strand;

  late BuiltMap<int, Helix> helices;
  late BuiltMap<String, HelixGroup> groups;
  late Geometry geometry;

  late bool show_domain_names;
  late bool drawing_potential_crossover;
  late bool moving_dna_ends;
  late String strand_tooltip;
  late ContextMenuStrand context_menu_strand;
  late BuiltMap<int, Point<double>> helix_idx_to_svg_position_map;
  late bool retain_strand_color_on_selection;
}

/// [side_selected_helix_idxs] is null if [only_display_selected_helices] is false
bool should_draw_domain(
  int helix_idx,
  BuiltSet<int>? side_selected_helix_idxs,
  bool only_display_selected_helices,
) => !only_display_selected_helices || side_selected_helix_idxs!.contains(helix_idx);

/// [side_selected_helix_idxs] is null if [only_display_selected_helices] is false
bool should_draw_loopout(
  int prev_helix_idx,
  int next_helix_idx,
  BuiltSet<int>? side_selected_helix_idxs,
  bool only_display_selected_helices,
) =>
    should_draw_domain(prev_helix_idx, side_selected_helix_idxs, only_display_selected_helices) &&
    should_draw_domain(next_helix_idx, side_selected_helix_idxs, only_display_selected_helices);

/// [side_selected_helix_idxs] is null if [only_display_selected_helices] is false
bool should_draw_extension(
  int adj_helix_idx,
  BuiltSet<int>? side_selected_helix_idxs,
  bool only_display_selected_helices,
) => should_draw_domain(adj_helix_idx, side_selected_helix_idxs, only_display_selected_helices);

class DesignMainStrandPathsComponent extends UiComponent2<DesignMainStrandPathsProps> with PureComponent {
  @override
  render() {
    return (Dom.g()..className = 'strand-paths')(_strand_paths());
  }

  List<ReactElement> _strand_paths() {
    Strand strand = props.strand;
    if (strand.substrands.first is Loopout) {
      throw StrandError(strand, 'loopouts at beginning of strand not supported');
    }
    if (strand.substrands.last is Loopout) {
      throw StrandError(strand, 'loopouts at end of strand not supported');
    }

    List<ReactElement> paths = [];
    List<ReactElement> ends = []; // add after so clicking on ends takes priority
    var substrand = strand.substrands.first;

    for (int i = 0; i < strand.substrands.length; i++) {
      substrand = strand.substrands[i];

      if (substrand is Domain) {
        Domain domain = substrand;
        Helix helix = props.helices[domain.helix]!;
        bool draw_domain = should_draw_domain(
          domain.helix,
          props.side_selected_helix_idxs,
          props.only_display_selected_helices,
        );
        if (draw_domain) {
          paths.add(
            (DesignMainDomain()
              ..domain = domain
              ..strand = props.strand
              ..transform = transform_of_helix2(props, domain.helix)
              ..context_menu_strand = props.context_menu_strand
              ..strand_color = strand.color
              ..selected = props.selected_domains_in_strand.contains(domain)
              ..helix = helix
              ..helices = {helix.idx: helix}.build()
              ..groups = {helix.group: props.groups[helix.group]!}.build()
              ..geometry = props.geometry
              ..strand_tooltip = props.strand_tooltip
              ..helix_svg_position = props.helix_idx_to_svg_position_map[helix.idx]!
              ..retain_strand_color_on_selection = props.retain_strand_color_on_selection
              ..key = "domain-$i")(),
          );

          // don't draw 5' or 3' end of a circular strand
          if (!props.strand.circular) {
            bool is_5p = true;
            for (DNAEnd end in [domain.dnaend_5p, domain.dnaend_3p]) {
              String key =
                  is_5p
                      ? "5'-end-$i${domain.is_first ? '-is_first' : ''}"
                      : "3'-end-$i${domain.is_last ? '-is_last' : ''}";
              bool end_selected = props.selected_ends_in_strand.contains(end);
              ends.add(
                (DesignMainDNAEnd()
                  ..domain = domain
                  ..is_5p = is_5p
                  ..transform = transform_of_helix2(props, domain.helix)
                  ..strand_color = strand.color
                  ..helix = helix
                  ..group = props.groups[helix.group]!
                  ..geometry = props.geometry
                  ..is_scaffold = props.strand.is_scaffold
                  ..selected = end_selected
                  ..strand = strand
                  ..context_menu_strand = props.context_menu_strand
                  ..moving_this_dna_end = props.moving_dna_ends && end_selected
                  ..drawing_potential_crossover = props.drawing_potential_crossover
                  ..helix_svg_position = props.helix_idx_to_svg_position_map[helix.idx]!
                  ..retain_strand_color_on_selection = props.retain_strand_color_on_selection
                  ..key = key)(),
              );
              is_5p = false;
            }
          }
        }
      } else if (substrand is Loopout) {
        Loopout loopout = substrand;
        Domain next_dom = strand.substrands[i + 1] as Domain;
        Domain prev_dom = strand.substrands[i - 1] as Domain;
        Helix prev_helix = props.helices[prev_dom.helix]!;
        Helix next_helix = props.helices[next_dom.helix]!;
        var prev_group = props.groups[prev_helix.group]!;
        var next_group = props.groups[next_helix.group]!;
        var prev_geometry = prev_group.geometry ?? props.geometry;
        var next_geometry = next_group.geometry ?? props.geometry;
        bool should = should_draw_loopout(
          prev_dom.helix,
          next_dom.helix,
          props.side_selected_helix_idxs,
          props.only_display_selected_helices,
        );
        if (should) {
          paths.add(
            (DesignMainLoopout()
              ..loopout = loopout
              ..strand = strand
              ..strand_color = strand.color
              ..prev_domain = prev_dom
              ..next_domain = next_dom
              ..prev_helix = prev_helix
              ..next_helix = next_helix
              ..selected = props.selected_loopouts_in_strand.contains(loopout)
              ..show_domain_names = props.show_domain_names
              ..helices = props.helices
              ..groups = props.groups
              ..geometry = props.geometry
              ..prev_geometry = prev_geometry
              ..next_geometry = next_geometry
              ..prev_helix_svg_position_y = props.helix_idx_to_svg_position_map[prev_helix.idx]!.y
              ..next_helix_svg_position_y = props.helix_idx_to_svg_position_map[next_helix.idx]!.y
              ..retain_strand_color_on_selection = props.retain_strand_color_on_selection
              ..key = "loopout-$i")(),
          );
        }
      } else if (substrand is Extension) {
        Extension ext = substrand;
        var is_5p_str = ext.is_5p ? "5'" : "3'";
        int adj_i = i == 0 ? 1 : i - 1;
        Domain adj_dom = strand.substrands[adj_i] as Domain;
        Helix adj_helix = props.helices[adj_dom.helix]!;
        bool should = should_draw_extension(
          adj_dom.helix,
          props.side_selected_helix_idxs,
          props.only_display_selected_helices,
        );
        if (should) {
          paths.add(
            (DesignMainExtension()
              ..ext = ext
              ..strand = strand
              ..helices = props.helices
              ..groups = props.groups
              ..geometry = props.geometry
              ..strand_color = strand.color
              ..transform = transform_of_helix2(props, adj_helix.idx)
              ..selected = props.selected_extensions_in_strand.contains(ext)
              ..retain_strand_color_on_selection = props.retain_strand_color_on_selection
              ..adjacent_domain = adj_dom
              ..adjacent_helix = adj_helix
              ..strand_tooltip = props.strand_tooltip
              ..adjacent_helix_svg_position = props.helix_idx_to_svg_position_map[adj_helix.idx]!
              ..key = "extension-${is_5p_str}-$i")(),
          );
          DNAEnd end = ext.dnaend_free;
          String key =
              ext.is_5p
                  ? "5'-end-$i${ext.is_5p ? '-ext-is_first' : ''}"
                  : "3'-end-$i${!ext.is_5p ? '-ext-is_last' : ''}";
          bool end_selected = props.selected_ends_in_strand.contains(end);
          ends.add(
            (DesignMainDNAEnd()
              ..ext = ext
              ..is_5p = ext.is_5p
              ..transform = transform_of_helix2(props, ext.adjacent_domain.helix)
              ..strand_color = strand.color
              ..helix = adj_helix
              ..group = props.groups[adj_helix.group]!
              ..geometry = props.geometry
              ..is_scaffold = props.strand.is_scaffold
              ..selected = end_selected
              ..strand = strand
              ..context_menu_strand = props.context_menu_strand
              ..moving_this_dna_end = props.moving_dna_ends && end_selected
              ..drawing_potential_crossover = props.drawing_potential_crossover
              ..helix_svg_position = props.helix_idx_to_svg_position_map[adj_helix.idx]!
              ..retain_strand_color_on_selection = props.retain_strand_color_on_selection
              ..key = key)(),
          );
        }
      }
    }

    int idx_crossover = 0;
    for (var crossover in strand.crossovers) {
      Domain prev_domain = strand.substrands[crossover.prev_domain_idx] as Domain;
      Domain next_domain = strand.substrands[crossover.next_domain_idx] as Domain;
      bool draw_prev_domain = should_draw_domain(
        prev_domain.helix,
        props.side_selected_helix_idxs,
        props.only_display_selected_helices,
      );
      bool draw_next_domain = should_draw_domain(
        next_domain.helix,
        props.side_selected_helix_idxs,
        props.only_display_selected_helices,
      );
      if (draw_prev_domain && draw_next_domain) {
        var crossover = strand.crossovers[idx_crossover++];

        paths.add(
          (DesignMainStrandCrossover()
            ..crossover = crossover
            ..strand = strand
            ..helices = props.helices
            ..groups = props.groups
            ..selected = props.selected_crossovers_in_strand.contains(crossover)
            ..prev_domain = prev_domain
            ..next_domain = next_domain
            ..geometry = props.geometry
            ..prev_domain_helix_svg_position_y = props.helix_idx_to_svg_position_map[prev_domain.helix]!.y
            ..next_domain_helix_svg_position_y = props.helix_idx_to_svg_position_map[next_domain.helix]!.y
            ..retain_strand_color_on_selection = props.retain_strand_color_on_selection
            ..key = 'crossover-paths-${idx_crossover - 1}')(),
        );
      }
    }

    return paths + ends;
  }
}

// transform svg_base_pos according to helix groups, and return absolute SVG path that can be
// drawn untransformed to go between helix groups
String crossover_path_description_between_groups(
  Domain prev_domain,
  Domain next_domain,
  BuiltMap<int, Helix> helices,
  Geometry geometry,
  BuiltMap<String, HelixGroup> groups,
  num prev_helix_svg_position_y,
  num next_helix_svg_position_y,
) {
  var prev_helix = helices[prev_domain.helix]!;
  var next_helix = helices[next_domain.helix]!;
  var prev_group = groups[prev_helix.group]!;
  var next_group = groups[next_helix.group]!;
  var prev_geometry = prev_group.geometry ?? geometry;
  var next_geometry = next_group.geometry ?? geometry;

  var start_svg = prev_helix.svg_base_pos(
    prev_domain.offset_3p,
    prev_domain.forward,
    prev_helix_svg_position_y,
    prev_geometry,
  );
  start_svg = prev_group.transform_point_main_view(start_svg, geometry);

  var end_svg = next_helix.svg_base_pos(
    next_domain.offset_5p,
    next_domain.forward,
    next_helix_svg_position_y,
    next_geometry,
  );
  end_svg = next_group.transform_point_main_view(end_svg, geometry);

  var vector_start_to_end = end_svg - start_svg;
  var normal_vector = util.rotate(vector_start_to_end, 90);
  var unit_normal_vector = normal_vector * (1.0 / normal_vector.magnitude);
  var scaled_normal_vector = unit_normal_vector * vector_start_to_end.magnitude * (1.0 / 10);
  var control = start_svg + (vector_start_to_end * 0.5) + scaled_normal_vector;

  var path =
      'M ${start_svg.x} ${start_svg.y} '
      'Q ${control.x} ${control.y} '
      '${end_svg.x} ${end_svg.y}';

  return path;
}

// treat svg_base_pos as though helix group has position = origin; let component calling this function
// do the transform based on its access to the group position
String crossover_path_description_within_group(
  Domain prev_domain,
  Domain next_domain,
  BuiltMap<int, Helix> helices,
  Geometry geometry,
  double prev_helix_svg_position_y,
  double next_helix_svg_position_y,
) {
  var prev_helix = helices[prev_domain.helix]!;
  var next_helix = helices[next_domain.helix]!;
  var start_svg = prev_helix.svg_base_pos(
    prev_domain.offset_3p,
    prev_domain.forward,
    prev_helix_svg_position_y,
    geometry,
  );
  var control = control_point_for_crossover_bezier_curve(
    prev_domain,
    next_domain,
    helices,
    prev_helix_svg_position_y,
    next_helix_svg_position_y,
    geometry: geometry,
  );
  var end_svg = next_helix.svg_base_pos(
    next_domain.offset_5p,
    next_domain.forward,
    next_helix_svg_position_y,
    geometry,
  );

  var path = 'M ${start_svg.x} ${start_svg.y} Q ${control.x} ${control.y} ${end_svg.x} ${end_svg.y}';

  return path;
}

Point<double> control_point_for_crossover_bezier_curve(
  Domain from_ss,
  Domain to_ss,
  BuiltMap<int, Helix> helices,
  num from_helix_svg_position_y,
  num to_helix_svg_position_y, {
  int delta = 0,
  required Geometry geometry,
}) {
  var from_helix = helices[from_ss.helix]!;
  var to_helix = helices[to_ss.helix]!;

  // normalized so that adjacent helices are distance 1
  var helix_distance_normalized =
      ((from_helix_svg_position_y - to_helix_svg_position_y) / geometry.distance_between_helices_svg).abs();

  var start_pos = from_helix.svg_base_pos(
    from_ss.offset_3p + delta,
    from_ss.forward,
    from_helix_svg_position_y,
    geometry,
  );
  var end_pos = to_helix.svg_base_pos(
    to_ss.offset_5p + delta,
    to_ss.forward,
    to_helix_svg_position_y,
    geometry,
  );
  bool from_strand_below = from_helix_svg_position_y > to_helix_svg_position_y;
  double midX = (start_pos.x + end_pos.x) / 2;
  double midY = (start_pos.y + end_pos.y) / 2;
  Point<double> mid = Point<double>(midX, midY);
  Point<double> control;
  Point<double> vector = end_pos - start_pos;
  Point<double> normal = Point<double>(vector.y, -vector.x);
  if ((!from_ss.forward && from_strand_below) || (from_ss.forward && !from_strand_below)) {
    normal = Point<double>(-vector.y, vector.x);
  }
  Point<double> unit_normal = normal * (1 / normal.magnitude);
  // This scale seems to look good even with many crossovers at same column,
  // e.g., long_range_crossovers.py in the examples directory.
  double scale = helix_distance_normalized * 0.5;
  Point<double> scale_normal = unit_normal * scale;
  control = mid + scale_normal * (geometry.base_width_svg / 2);
  return control;
}

// This was in an earlier version. It renders faster than drawing each domain and crossover/loopout
// as a separate SVG object. However, then they are not separate objects and it makes responding to click
// and other pointer events much more difficult. I'm keeping it here just in case but I doubt it will be
// used again.
//  _draw_strand_lines_single_path() {
//    if (this.strand.substrands.length == 0) {
//      return;
//    }
//    var substrand = this.strand.substrands.first;
//    var helix = app.state.design.helices[substrand.helix_idx];
//    var start_svg = helix.svg_base_pos(substrand.offset_5p, substrand.forward);
//    var path_cmds = ['M ${start_svg.x} ${start_svg.y}'];
//    for (int i = 0; i < this.strand.substrands.length; i++) {
//      // substrand line
//      var end_svg = helix.svg_base_pos(substrand.offset_3p, substrand.forward);
//      path_cmds.add('L ${end_svg.x} ${end_svg.y}');
//
//      // crossover line/arc
//      if (i < this.strand.substrands.length - 1) {
//        var old_substrand = substrand;
//        substrand = this.strand.substrands[i + 1];
//        helix = app.state.design.helices[substrand.helix_idx];
//        start_svg = helix.svg_base_pos(substrand.offset_5p, substrand.forward);
//        var control = _control_point_for_crossover_bezier_curve(old_substrand, substrand);
//        path_cmds.add('Q ${control.x} ${control.y} ${start_svg.x} ${start_svg.y}');
//      }
//    }
//
//    var path = svg.PathElement();
//    path.attributes = {
//      'id': substrand_line_id(substrand),
//      'class': 'domain-line',
//      'stroke': strand.color.toHexColor().toCssString(),
//      'fill': 'none',
//      'd': path_cmds.join(' '),
//    };
//    this.root_element.children.add(path);
//  }
