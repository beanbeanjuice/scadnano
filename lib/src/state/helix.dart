import 'dart:math';

import 'package:built_value/serializer.dart';
import 'package:built_collection/built_collection.dart';
import '../state/design.dart';
import '../state/position3d.dart';
import '../state/unused_fields.dart';

import '../json_serializable.dart';
import '../serializers.dart';
import 'geometry.dart';
import 'grid.dart';
import 'strand.dart';
import 'grid_position.dart';
import 'address.dart';
import '../constants.dart' as constants;
import '../util.dart' as util;

import 'package:built_value/built_value.dart';

part 'helix.g.dart';

/// Represents a double helix. However, a [Helix] doesn't have to have any [Strand]s on it.
abstract class Helix with BuiltJsonSerializable, UnusedFields implements Built<Helix, HelixBuilder> {
  Helix._() {
    if (grid_position == null && position_ == null) {
      throw ArgumentError(
        'exactly one of Helix.grid_position and Helix.position should be null, '
        'but both are null.',
      );
    }
    if (grid_position != null && position_ != null) {
      throw ArgumentError(
        'exactly one of Helix.grid_position and Helix.position should be null, '
        'but both are non-null.',
      );
    }
  }

  static Serializer<Helix> get serializer => _$helixSerializer;

  factory Helix.from([void Function(HelixBuilder) updates]) = _$Helix;

  @memoized
  int get hashCode;

  /************************ end BuiltValue boilerplate ************************/

  factory Helix({
    required int idx,
    Grid? grid = null,
    GridPosition? grid_position = null,
    double roll = constants.default_roll,
    int min_offset = 0,
    int? major_tick_start = null,
    int max_offset = constants.default_max_offset,
    bool invert_y = false,
    Position3D? position = null,
    Point<double>? svg_position = null,
    Iterable<int>? major_tick_periodic_distances = null,
    String group = constants.default_group_name,
  }) {
    if (grid == null) {
      grid = Grid.none;
    }
    if (major_tick_start == null) {
      major_tick_start = min_offset;
    }
    if (grid_position == null && grid != Grid.none) {
      grid_position = GridPosition(0, idx);
    }
    if (major_tick_periodic_distances == null) {
      major_tick_periodic_distances = [];
    }
    return Helix.from(
      (b) =>
          b
            ..idx = idx
            ..group = group
            ..grid = grid
            ..grid_position = grid_position?.toBuilder()
            ..position_ = position?.toBuilder()
            ..roll = roll
            ..min_offset = min_offset
            ..max_offset = max_offset
            ..major_tick_start = major_tick_start
            ..major_tick_periodic_distances.replace(major_tick_periodic_distances!)
            ..unused_fields.replace({}),
    );
  }

  static void _initializeBuilder(HelixBuilder b) {
    b.group = constants.default_group_name;
    b.min_offset = 0;
    b.roll = constants.default_roll;
  }

  /// unique identifier of used helix; also index indicating order to show
  /// in main view from top to bottom (unused helices not shown in main view)
  /// by default.
  int get idx;

  Grid get grid;

  // Geometry get geometry;

  String get group;

  /// position within square/hex/honeycomb integer grid (side view)
  GridPosition? get grid_position;

  Position3D? get position_;

  Position3D position(Geometry geometry) =>
      position_ ?? util.grid_position_to_position3d(this.grid_position!, grid, geometry);

  /// Helix rotation of the backbone of the forward strand at the helix's minimum base offset. (y-z)
  double get roll;

  /// 1 plus the maximum allowed offset of Substrand that can be drawn on this Helix. i.e. EXCLUSIVE.
  int get max_offset;

  /// Minimum allowed offset of Substrand that can be drawn on this Helix.
  int get min_offset;

  // If regular or periodic distances are used, this is the starting offset
  int get major_tick_start;

  // major_tick_distance
  BuiltList<int> get major_tick_periodic_distances;

  int? get major_tick_distance =>
      major_tick_periodic_distances.length != 1 ? null : major_tick_periodic_distances.first;

  BuiltList<int>? get major_ticks;

  Position3D default_position(Geometry geometry) {
    double z = min_offset * geometry.rise_per_base_pair;

    // normalized so helices are diameter 1
    Point<double> point_zy;
    if (grid == Grid.square) {
      point_zy = Point<double>(this.grid_position!.h as double, this.grid_position!.v as double);
    } else if (grid == Grid.hex) {
      point_zy = util.hex_grid_position_to_position2d_diameter_1_circles(this.grid_position!);
    } else if (grid == Grid.honeycomb) {
      point_zy = util.honeycomb_grid_position_to_position2d_diameter_1_circles(this.grid_position!);
    } else {
      throw AssertionError('should not be accessing default_position if grid_position is not defined');
    }

    double y = point_zy.y * geometry.distance_between_helices_nm;
    double x = point_zy.x * geometry.distance_between_helices_nm;
    Position3D pos = Position3D(x: x, y: y, z: z);
    return pos;
  }

  @memoized
  bool get has_grid_position => this.grid_position != null;

  @memoized
  bool get has_position => this.position_ != null;

  /// Gets 3D position (in "SVG coordinates" for the x,y,z) of Helix (offset 0).
  /// If [null], then [grid_position] must be non-[null], and it is auto-calculated from that.
  Position3D position3d(Geometry geometry) {
    if (position_ != null) {
      return position_!;
    }
    return this.default_position(geometry);
  }

  /// Calculates x-y angle in degrees, according to position3d(), from this [Helix] to [other].
  double angle_to(Helix other, Geometry geometry) {
    var pos1 = this.position3d(geometry);
    var pos2 = other.position3d(geometry);
    double x = pos2.x - pos1.x;
    double y = pos2.y - pos1.y;
    double angle_radians = (atan2(x, -y)) % (2 * pi); // using SVG "reverse y" coordinates
    return util.to_degrees(angle_radians);
  }

  @memoized
  bool get has_default_group => group == constants.default_group_name;

  @memoized
  bool get has_default_roll => util.are_close(roll, constants.default_roll);

  @memoized
  bool get has_default_major_tick_distance => major_tick_distance == null;

  @memoized
  bool get has_default_major_tick_periodic_distances => major_tick_periodic_distances.isEmpty;

  @memoized
  bool get has_default_major_tick_start => major_tick_start == min_offset;

  @memoized
  bool get has_default_major_ticks => major_ticks == null;

  @memoized
  bool get has_major_tick_distance => !has_default_major_tick_distance;

  @memoized
  bool get has_major_ticks => !has_default_major_ticks;

  @memoized
  bool get has_major_tick_periodic_distances => major_tick_periodic_distances.length >= 2;

  Object to_json_serializable({bool suppress_indent = false}) {
    Map<String, dynamic> json_map = {};

    // if we have major ticks or position, it's harder to read Helix on one line,
    // so don't wrap it in NoIndent, but still wrap longer sub-objects in them
    bool use_no_indent = has_default_major_ticks && !has_position;

    if (!has_default_roll) {
      json_map[constants.roll_key] = util.to_int_if_close(roll);
    }

    if (has_grid_position) {
      var gp = this.grid_position!.to_json_serializable(suppress_indent: suppress_indent);
      json_map[constants.grid_position_key] = suppress_indent && !use_no_indent ? NoIndent(gp) : gp;
    }

    if (has_position) {
      var pos = this.position_!.to_json_serializable(suppress_indent: suppress_indent);
      json_map[constants.position_key] = suppress_indent && !use_no_indent ? NoIndent(pos) : pos;
    }

    if (!has_default_major_tick_distance) {
      json_map[constants.major_tick_distance_key] = this.major_tick_distance!;
    }

    if (!has_default_major_tick_start) {
      json_map[constants.major_tick_start_key] = major_tick_start;
    }

    if (!has_default_group) {
      json_map[constants.group_key] = group;
    }

    if (has_major_tick_periodic_distances) {
      var distances = major_tick_periodic_distances.toList();
      json_map[constants.major_tick_periodic_distances_key] =
          suppress_indent && !use_no_indent ? NoIndent(distances) : distances;
    }

    json_map.addAll(unused_fields.toMap());

    if (!has_default_major_ticks) {
      var ticks = this.major_ticks!.toList();
      json_map[constants.major_ticks_key] = suppress_indent && !use_no_indent ? NoIndent(ticks) : ticks;
    }

    json_map[constants.idx_on_helix_key] = idx;

    return suppress_indent && use_no_indent ? NoIndent(json_map) : json_map;
  }

  /// Gets main view SVG position of "center of base" (middle of square representing base)
  /// given helix idx and offset,  depending on whether strand is going forward or not.
  /// This function also requires svg_position_y, the y coordinate of the helix
  /// svg position.
  /// This is relative to the starting point of the Helix.
  Point<double> svg_base_pos(int offset, bool forward, num svg_position_y, Geometry geometry) {
    double x = geometry.base_width_svg / 2.0 + offset * geometry.base_width_svg;

    // svg_height is height of whole helix, including both forward and reverse strand
    // must divide by 2 to get height of one strand, then divide by 2 again to go halfway into square
    double y = this.svg_height(geometry) / 4.0 + svg_position_y;
    if (!forward) {
      y += geometry.base_height_svg;
    }
    return Point<double>(x, y);
  }

  int svg_x_to_offset(num x, num helix_svg_position_x, Geometry geometry) {
    var offset = ((x - helix_svg_position_x) / geometry.base_width_svg).floor() + min_offset;
    return offset;
  }

  // Don't know why but Firefox knows about the SVG translation already so no need to correct for it.
  bool svg_y_is_forward(num y, num helix_svg_position_y, Geometry geometry) {
    var relative_y = (y - helix_svg_position_y);
    // return relative_y < 10;
    return relative_y < geometry.base_height_svg;
  }

  static HelixBuilder from_json(Map<String, dynamic> json_map) {
    var helix_builder = HelixBuilder();

    helix_builder.unused_fields = util.unused_fields_map(json_map, constants.helix_keys);

    if (json_map.containsKey(constants.major_tick_distance_key)) {
      int major_tick_distance = json_map[constants.major_tick_distance_key]! as int;
      helix_builder.major_tick_periodic_distances = ListBuilder<int>([major_tick_distance]);
    }

    if (json_map.containsKey(constants.major_ticks_key)) {
      List<int> major_ticks_json = List<int>.from(json_map[constants.major_ticks_key]!);
      helix_builder.major_ticks = ListBuilder<int>(List<int>.from(major_ticks_json));
    }

    if (json_map.containsKey(constants.major_tick_periodic_distances_key)) {
      List<int> major_tick_periodic_distances_json = List<int>.from(
        json_map[constants.major_tick_periodic_distances_key]!,
      );
      helix_builder.major_tick_periodic_distances = ListBuilder<int>(
        List<int>.from(major_tick_periodic_distances_json),
      );
    }

    if (json_map.containsKey(constants.grid_position_key)) {
      List<dynamic> gp_list = json_map[constants.grid_position_key]!;
      if (!(gp_list.length == 2)) {
        throw ArgumentError(
          "list of grid_position coordinates must be length 2 but this is the list: ${gp_list}",
        );
      }
      helix_builder.grid_position = GridPosition.from_list(gp_list).toBuilder();
    }

    if (json_map.containsKey(constants.max_offset_key)) {
      var max_offset_json = json_map[constants.max_offset_key];
      if (max_offset_json != null) {
        helix_builder.max_offset = json_map[constants.max_offset_key]! as int;
      }
    }

    helix_builder.group = util.optional_field(json_map, constants.group_key, constants.default_group_name);

    // XXX: many of these fields are not nullable. But they are allowed to be null in the builder,
    // before we call build(). We communicate to the Design that they need to be populated with
    // defaults by allowing them to be null here. These are for fields where the default requires
    // knowledge of the whole design (e.g., min and max offset are based on offsets of Domains on
    // the helix).
    helix_builder.min_offset = util.optional_field_with_null_default(json_map, constants.min_offset_key);
    helix_builder.major_tick_start = util.optional_field_with_null_default(
      json_map,
      constants.major_tick_start_key,
    );
    helix_builder.idx = util.optional_field_with_null_default(json_map, constants.idx_on_helix_key);
    helix_builder.roll = util.optional_field(json_map, constants.roll_key, constants.default_roll);

    if (json_map.containsKey(constants.major_tick_distance_key) &&
        json_map.containsKey(constants.major_tick_periodic_distances_key)) {
      throw IllegalDesignError(
        'helix ${helix_builder.idx ?? ""} has both keys '
        '${constants.major_tick_distance_key} and '
        '${constants.major_tick_periodic_distances_key}. At most one is allow to be specified.',
      );
    }

    Position3D? position = Position3D.get_position_from_helix_json_map(json_map);
    helix_builder.position_ = position?.toBuilder();

    return helix_builder;
  }

  double svg_width(Geometry geometry) => geometry.base_width_svg * this.num_bases;

  double svg_height(Geometry geometry) => geometry.base_height_svg * 2;

  @memoized
  int get num_bases => this.max_offset - this.min_offset;

  /// Calculates full list of major tick marks, in sorted order,
  /// whether using [Helix.major_tick_distance], or [Helix.major_ticks].
  /// They are used in reverse order to determine precedence. (e.g., [Helix.major_ticks]
  /// overrides [Helix.major_tick_distance].
  @memoized
  BuiltList<int> get calculate_major_ticks {
    List<int> ticks = [];
    if (this.has_major_ticks) {
      var sorted_ticks = this.major_ticks!.toList();
      sorted_ticks.sort();
      ticks = sorted_ticks;
    } else if (has_major_tick_periodic_distances) {
      int distance_idx = -1;
      int? distance = null;
      for (int tick = major_tick_start; tick <= max_offset; tick += distance) {
        distance_idx = (distance_idx + 1) % major_tick_periodic_distances.length;
        distance = major_tick_periodic_distances[distance_idx];
        ticks.add(tick);
      }
    } else {
      int distance =
          major_tick_distance != null && this.major_tick_distance! > 0
              ? this.major_tick_distance!
              : grid.default_major_tick_distance;
      if (distance > 0) {
        ticks = [for (int tick = major_tick_start; tick <= max_offset; tick += distance) tick];
      }
    }
    return ticks.build();
  }

  double backbone_angle_at_offset(int offset, bool forward, Geometry geometry) {
    // Computes the backbone angle at *offset* for the strand in the direction given by *forward*.
    //
    // :param offset:
    //     offset on this helix
    // :param forward:
    //     whether to compute angle for the forward or reverse strand
    // :return:
    //     backbone angle at *offset* for the strand in the direction given by *forward*.
    var degrees_per_base = 360 / geometry.bases_per_turn;
    var angle = this.roll + offset * degrees_per_base;
    if (!forward) {
      angle += geometry.minor_groove_angle;
    }
    angle %= 360;
    return angle;
  }

  Helix relax_roll(BuiltMap<int, Helix> helices, BuiltList<Address> crossover_addresses, Geometry geometry) {
    var roll_delta = compute_relaxed_roll_delta(helices, crossover_addresses, geometry);
    var new_helix = this.rebuild((b) => b..roll = roll + roll_delta);
    return new_helix;
  }

  double compute_relaxed_roll_delta(
    BuiltMap<int, Helix> helices,
    BuiltList<Address> crossover_addresses,
    Geometry geometry,
  ) {
    List<(double, double)> angles = [];
    for (var address in crossover_addresses) {
      var other_helix = helices[address.helix_idx]!;
      var angle_of_other_helix = util.angle_from_helix_to_helix(this, other_helix, geometry);
      var crossover_angle = this.backbone_angle_at_offset(address.offset, address.forward, geometry);
      (double, double) relative_angle = (crossover_angle, angle_of_other_helix);
      angles.add(relative_angle);
    }
    var angle = util.minimum_strain_angle(angles);
    return angle;
  }
}
