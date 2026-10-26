class_name FixedWorldDefinition
extends RefCounted

# One deliberately designed planet for development and visual evaluation.
# Everything here is hand-authored in degrees: Vector2(longitude 0..360, latitude 90..-90),
# with the world wrapping at longitude 0/360 inside the Western Ocean.
#
# This file is only the authored description. WorldFieldBuilder turns it into WorldMapData;
# a future world generator can replace this file by producing a definition of the same shape.

const WORLD_SIZE: Vector2 = Vector2(7200.0, 3600.0)
const TERRAIN_SIZE: Vector2i = Vector2i(1024, 512)
const POLITICAL_SIZE: Vector2i = Vector2i(512, 256)

# Coastline roughening uses fixed noise so coasts are irregular below the scale of the
# authored outlines. The value is a constant: the same world is built on every run.
const COASTLINE_NOISE_SEED: int = 1187

const LANDMASSES: Array = [
	{"name": "Westreach", "outline": [
		Vector2(38, 63), Vector2(44, 68), Vector2(52, 71), Vector2(60, 72), Vector2(67, 70), Vector2(74, 72),
		Vector2(82, 71), Vector2(90, 68), Vector2(97, 66), Vector2(101, 62), Vector2(98, 58), Vector2(102, 55),
		Vector2(100, 51), Vector2(96, 49), Vector2(92, 48.5), Vector2(89, 46), Vector2(91, 43), Vector2(96, 41),
		Vector2(99, 37), Vector2(97, 32), Vector2(93, 28), Vector2(89, 23), Vector2(86, 18), Vector2(84, 13),
		Vector2(87, 9), Vector2(93, 7), Vector2(99, 3), Vector2(102, -3), Vector2(100, -9), Vector2(97, -15),
		Vector2(93, -21), Vector2(89, -27), Vector2(84, -33), Vector2(79, -39), Vector2(75, -43), Vector2(71, -41),
		Vector2(70, -35), Vector2(68, -28), Vector2(66, -20), Vector2(64, -12), Vector2(62, -4), Vector2(65, 3),
		Vector2(70, 8), Vector2(75, 12), Vector2(74, 18), Vector2(70, 22), Vector2(64, 25), Vector2(57, 29),
		Vector2(51, 32), Vector2(46, 37), Vector2(43, 42), Vector2(40, 47), Vector2(36, 51), Vector2(34, 56),
		Vector2(35, 60)]},
	{"name": "Greyholm", "outline": [
		Vector2(113, 71), Vector2(118, 76), Vector2(127, 79), Vector2(137, 78), Vector2(143, 73), Vector2(140, 67),
		Vector2(133, 63), Vector2(124, 61), Vector2(117, 64)]},
	{"name": "Corran Isles", "outline": [
		Vector2(118, 39.5), Vector2(122, 41.5), Vector2(126, 39.5), Vector2(124.5, 36.5), Vector2(120, 36.5)]},
	{"name": "Heartland", "outline": [
		Vector2(149, 61), Vector2(155, 67), Vector2(164, 70), Vector2(174, 72), Vector2(186, 72), Vector2(197, 74),
		Vector2(210, 73), Vector2(222, 74), Vector2(234, 72), Vector2(246, 71), Vector2(255, 67), Vector2(256.5, 62),
		Vector2(255, 57), Vector2(251, 53), Vector2(254, 48), Vector2(251, 42), Vector2(246, 38), Vector2(240, 37),
		Vector2(235, 38), Vector2(231, 40), Vector2(228, 36.5), Vector2(225, 34.5), Vector2(222, 35.5), Vector2(219, 39),
		Vector2(213, 41), Vector2(208, 40), Vector2(206, 36), Vector2(204, 32.5), Vector2(201, 33), Vector2(199, 37),
		Vector2(196, 40), Vector2(190, 41.5), Vector2(185, 40), Vector2(181, 37), Vector2(176, 37.5), Vector2(171, 40),
		Vector2(165, 41), Vector2(159, 39), Vector2(154, 40), Vector2(151, 43), Vector2(147, 46), Vector2(142, 47),
		Vector2(139, 50), Vector2(141, 53.5), Vector2(146, 52.5), Vector2(150, 54), Vector2(148, 57.5)]},
	{"name": "Isle of Wend", "outline": [
		Vector2(130, 54), Vector2(133, 58), Vector2(137, 57.5), Vector2(136.5, 53.5), Vector2(132, 52)]},
	{"name": "Svalgrim", "outline": [
		Vector2(198, 77), Vector2(204, 80.5), Vector2(213, 80.5), Vector2(216, 77), Vector2(209, 75.5)]},
	{"name": "Southland", "outline": [
		Vector2(157, 28), Vector2(163, 30.5), Vector2(170, 30), Vector2(177, 31.5), Vector2(184, 31), Vector2(191, 30),
		Vector2(198, 29.5), Vector2(203, 28), Vector2(209, 29), Vector2(215, 31.5), Vector2(221, 30), Vector2(228, 30),
		Vector2(235, 30), Vector2(241, 27), Vector2(244, 22), Vector2(246, 16), Vector2(251, 12), Vector2(257, 9),
		Vector2(254, 4), Vector2(247, 2), Vector2(245, -5), Vector2(243, -13), Vector2(239, -21), Vector2(233, -29),
		Vector2(225, -34.5), Vector2(217, -35.5), Vector2(211, -32), Vector2(207, -25), Vector2(203, -17), Vector2(199, -10),
		Vector2(194, -5.5), Vector2(188, -4.5), Vector2(182, -3), Vector2(176, -1.5), Vector2(169, 0.5), Vector2(163, 3),
		Vector2(157, 7.5), Vector2(153, 13), Vector2(151, 19), Vector2(153, 24)]},
	{"name": "Jade Reach", "outline": [
		Vector2(262, 63), Vector2(268, 67), Vector2(278, 70), Vector2(290, 72), Vector2(303, 71), Vector2(316, 70),
		Vector2(328, 67), Vector2(338, 63), Vector2(345, 58), Vector2(343, 52), Vector2(338, 48.5), Vector2(334, 49),
		Vector2(331, 45.5), Vector2(334, 42), Vector2(338, 38), Vector2(339, 33), Vector2(335, 28), Vector2(329, 24),
		Vector2(323, 21), Vector2(316, 19), Vector2(310, 20.5), Vector2(305, 17), Vector2(302, 11), Vector2(299, 4),
		Vector2(296, -1), Vector2(293, 1), Vector2(290, 6), Vector2(288, 12), Vector2(285, 17), Vector2(280, 20),
		Vector2(274, 23), Vector2(269, 27), Vector2(265, 31), Vector2(263, 37), Vector2(262, 42), Vector2(265, 46),
		Vector2(263, 52), Vector2(260, 57)]},
	{"name": "Sammar", "outline": [
		Vector2(307, 7), Vector2(312, 9), Vector2(318, 8), Vector2(320, 4), Vector2(316, 1), Vector2(310, 2)]},
	{"name": "Ulo", "outline": [
		Vector2(322, -1), Vector2(327, 1), Vector2(333, 0), Vector2(334, -4), Vector2(329, -7), Vector2(323, -5.5)]},
	{"name": "Tessel", "outline": [
		Vector2(336, 5), Vector2(341, 7), Vector2(345, 3), Vector2(343, -1), Vector2(338, 0)]},
	{"name": "Long Kava", "outline": [
		Vector2(298, -8), Vector2(304, -8.5), Vector2(311, -10), Vector2(318, -13), Vector2(317, -16.5), Vector2(310, -15),
		Vector2(303, -13), Vector2(298, -11.5)]},
	{"name": "Austral", "outline": [
		Vector2(298, -23), Vector2(305, -20.5), Vector2(312, -21), Vector2(318, -23.5), Vector2(325, -20), Vector2(332, -22.5),
		Vector2(338, -27), Vector2(341, -33), Vector2(338, -38), Vector2(332, -42.5), Vector2(324, -42), Vector2(318, -38.5),
		Vector2(312, -37), Vector2(305, -38), Vector2(299, -35), Vector2(295, -29)]},
	{"name": "Fell Isle", "outline": [
		Vector2(135, -45.5), Vector2(140, -43.5), Vector2(145, -46), Vector2(143, -49.5), Vector2(137, -49.5)]},
	# The polar shelf crosses the wrap seam; the rasterizer wraps it around the planet.
	{"name": "The White Shelf", "outline": [
		Vector2(-10, -68), Vector2(10, -64), Vector2(30, -67), Vector2(50, -63), Vector2(70, -68), Vector2(90, -65),
		Vector2(110, -70), Vector2(130, -66), Vector2(150, -63), Vector2(170, -69), Vector2(190, -66), Vector2(210, -63),
		Vector2(230, -67), Vector2(250, -65), Vector2(270, -70), Vector2(290, -66), Vector2(310, -63), Vector2(330, -68),
		Vector2(350, -65), Vector2(370, -68), Vector2(370, -90), Vector2(-10, -90)]},
]

# Inland water bodies, as ellipses: radius in degrees of longitude/latitude.
const LAKES: Array = [
	{"name": "Lake Callow", "center": Vector2(70, 53), "radius": Vector2(3.5, 2.0)},
	{"name": "Mirrormere", "center": Vector2(178, 58.5), "radius": Vector2(2.6, 1.3)},
	{"name": "Hrothvatn", "center": Vector2(240.5, 64), "radius": Vector2(3.0, 1.4)},
	{"name": "Lake Umbra", "center": Vector2(225, -3.5), "radius": Vector2(3.0, 2.4)},
	{"name": "Jade Mere", "center": Vector2(303, 58), "radius": Vector2(2.6, 1.2)},
]

# Mountain ranges follow their crest line. Height 0..1, width in degrees.
const MOUNTAIN_RANGES: Array = [
	{"name": "The Thornspine", "height": 0.9, "width": 2.6, "path": [
		Vector2(41, 62), Vector2(40, 55), Vector2(43, 47), Vector2(48, 40), Vector2(54, 34), Vector2(62, 28),
		Vector2(70, 22), Vector2(74, 15), Vector2(70, 7), Vector2(66, 0), Vector2(65, -8), Vector2(67, -17),
		Vector2(69, -27), Vector2(72, -37)]},
	{"name": "The Greywold", "height": 0.35, "width": 3.2, "path": [Vector2(86, 62), Vector2(90, 57), Vector2(93, 52)]},
	{"name": "Greyholm Peaks", "height": 0.6, "width": 3.0, "path": [Vector2(122, 72), Vector2(130, 74), Vector2(137, 71)]},
	{"name": "The Skarn", "height": 0.5, "width": 2.4, "path": [Vector2(166, 62), Vector2(172, 66), Vector2(180, 69)]},
	{"name": "The Crownspine", "height": 0.95, "width": 2.2, "path": [
		Vector2(184, 45), Vector2(190, 47.5), Vector2(197, 48), Vector2(204, 47), Vector2(211, 45.5), Vector2(216, 46.5)]},
	{"name": "The Ironback", "height": 0.55, "width": 2.0, "path": [
		Vector2(222, 51), Vector2(223, 57), Vector2(225, 63), Vector2(224, 70)]},
	{"name": "The Avennines", "height": 0.42, "width": 1.5, "path": [Vector2(207, 39), Vector2(205, 36), Vector2(203.5, 33.5)]},
	{"name": "The Redfangs", "height": 0.6, "width": 2.2, "path": [
		Vector2(158, 25), Vector2(165, 27), Vector2(172, 27.5), Vector2(178, 27)]},
	{"name": "The Sunwall", "height": 0.7, "width": 2.5, "path": [
		Vector2(228, 10), Vector2(232, 4), Vector2(234, -3), Vector2(233, -9)]},
	{"name": "The Dragonback", "height": 0.55, "width": 2.5, "path": [
		Vector2(238, -16), Vector2(234, -24), Vector2(228, -31)]},
	{"name": "The Skyroof", "height": 1.0, "width": 2.6, "path": [
		Vector2(270, 31), Vector2(277, 29.5), Vector2(285, 29), Vector2(293, 30), Vector2(300, 32)]},
	{"name": "Jadewall", "height": 0.5, "width": 2.2, "path": [
		Vector2(288, 51), Vector2(296, 54), Vector2(305, 56), Vector2(312, 55)]},
	{"name": "The Eastern Ranges", "height": 0.45, "width": 2.0, "path": [
		Vector2(325, 60), Vector2(333, 57), Vector2(339, 52)]},
	{"name": "The Ghats", "height": 0.4, "width": 1.6, "path": [Vector2(289, 15), Vector2(291, 8), Vector2(294, 2)]},
	{"name": "The Morrow Range", "height": 0.35, "width": 2.0, "path": [
		Vector2(336, -25), Vector2(339, -32), Vector2(336, -38)]},
]

# Raised ground without sharp ridges: plateaus and uplands. Radius in degrees.
const HIGHLANDS: Array = [
	{"center": Vector2(284, 37.5), "radius": Vector2(10, 5.5), "height": 0.42},
	{"center": Vector2(230, 2), "radius": Vector2(6, 7), "height": 0.32},
	{"center": Vector2(163, 54), "radius": Vector2(4, 3), "height": 0.12},
	{"center": Vector2(64, 32), "radius": Vector2(7, 5), "height": 0.2},
	{"center": Vector2(196, 20), "radius": Vector2(5, 4), "height": 0.15},
	{"center": Vector2(320, -28), "radius": Vector2(8, 5), "height": 0.08},
]

# Authored climate: deserts and rain shadows (negative) and wet coasts and basins (positive),
# added on top of the latitude climate bands.
const MOISTURE_ZONES: Array = [
	{"center": Vector2(64, 40), "radius": Vector2(10, 8), "amount": -0.3},
	{"center": Vector2(63, 30), "radius": Vector2(7, 5), "amount": -0.45},
	{"center": Vector2(39, 52), "radius": Vector2(4, 8), "amount": 0.3},
	{"center": Vector2(82, -2), "radius": Vector2(16, 9), "amount": 0.35},
	{"center": Vector2(84, -24), "radius": Vector2(8, 7), "amount": 0.15},
	{"center": Vector2(58, 62), "radius": Vector2(10, 6), "amount": 0.15},
	{"center": Vector2(66, -24), "radius": Vector2(3, 8), "amount": -0.4},
	{"center": Vector2(246, 49), "radius": Vector2(9, 6), "amount": -0.35},
	{"center": Vector2(155, 58), "radius": Vector2(8, 8), "amount": 0.15},
	{"center": Vector2(182, 52), "radius": Vector2(24, 9), "amount": 0.08},
	{"center": Vector2(205, 38), "radius": Vector2(20, 4), "amount": -0.12},
	{"center": Vector2(188, 20), "radius": Vector2(22, 10), "amount": -0.75},
	{"center": Vector2(225, 20), "radius": Vector2(14, 8), "amount": -0.6},
	{"center": Vector2(182, 2), "radius": Vector2(16, 8), "amount": 0.35},
	{"center": Vector2(210, -23), "radius": Vector2(8, 7), "amount": -0.4},
	{"center": Vector2(250, 10), "radius": Vector2(6, 5), "amount": -0.4},
	{"center": Vector2(284, 45), "radius": Vector2(12, 6), "amount": -0.55},
	{"center": Vector2(270, 52), "radius": Vector2(9, 6), "amount": -0.3},
	{"center": Vector2(318, 33), "radius": Vector2(18, 10), "amount": 0.32},
	{"center": Vector2(294, 10), "radius": Vector2(8, 8), "amount": 0.2},
	{"center": Vector2(296, 21), "radius": Vector2(10, 8), "amount": 0.35},
	{"center": Vector2(290, 62), "radius": Vector2(16, 6), "amount": 0.15},
	{"center": Vector2(318, -29), "radius": Vector2(16, 8), "amount": -0.65},
	{"center": Vector2(320, -2), "radius": Vector2(18, 10), "amount": 0.3},
]

const FOREST_ZONES: Array = [
	{"center": Vector2(58, 61), "radius": Vector2(11, 6), "amount": 0.45},
	{"center": Vector2(90, 58), "radius": Vector2(6, 5), "amount": 0.2},
	{"center": Vector2(205, 66), "radius": Vector2(18, 4), "amount": 0.25},
	{"center": Vector2(215, 54), "radius": Vector2(5, 4), "amount": 0.45},
	{"center": Vector2(240, 58), "radius": Vector2(8, 5), "amount": 0.35},
	{"center": Vector2(290, 62), "radius": Vector2(16, 6), "amount": 0.4},
	{"center": Vector2(184, 1), "radius": Vector2(14, 6), "amount": 0.3},
]

# Rivers run from source to mouth. Widths are world units at the source and the mouth.
# A river with "joins" is a tributary that ends in another river instead of the sea.
const RIVERS: Array = [
	{"name": "Great Meander", "major": true, "width": Vector2(1.0, 4.0), "path": [
		Vector2(50, 50), Vector2(56, 49), Vector2(62, 47.5), Vector2(66, 51), Vector2(70, 53), Vector2(74, 51),
		Vector2(78, 48), Vector2(84, 46.2), Vector2(87, 45.8), Vector2(89.5, 45.5), Vector2(91, 45.3)]},
	{"name": "Frostrun", "major": false, "width": Vector2(0.8, 2.4), "path": [
		Vector2(62, 60), Vector2(70, 63), Vector2(78, 66), Vector2(85, 69), Vector2(87, 71.5)]},
	{"name": "Sunward", "major": false, "width": Vector2(0.8, 2.4), "path": [
		Vector2(56, 38), Vector2(64, 36), Vector2(72, 34), Vector2(82, 33), Vector2(92, 31), Vector2(98.5, 31)]},
	{"name": "Verdance", "major": true, "width": Vector2(1.2, 5.0), "path": [
		Vector2(67, -3), Vector2(73, -1), Vector2(80, -2.5), Vector2(87, -0.5), Vector2(94, -1.5), Vector2(100, -2.5),
		Vector2(103.5, -3)]},
	{"name": "Pampas River", "major": false, "width": Vector2(0.8, 2.2), "path": [
		Vector2(70, -22), Vector2(76, -25), Vector2(82, -29), Vector2(86, -30.5), Vector2(89, -30.5)]},
	{"name": "Saelle", "major": true, "width": Vector2(1.0, 3.6), "path": [
		Vector2(186, 49), Vector2(180, 49.5), Vector2(174, 48.5), Vector2(168, 47.5), Vector2(161, 46.5), Vector2(155, 45.5),
		Vector2(151, 44.5), Vector2(148, 44)]},
	{"name": "Wend", "major": true, "width": Vector2(1.0, 3.4), "path": [
		Vector2(196, 49.5), Vector2(195, 53), Vector2(194, 58), Vector2(192, 63), Vector2(191, 67), Vector2(190, 71),
		Vector2(189.5, 74)]},
	{"name": "Tarrow", "major": false, "joins": "Wend", "width": Vector2(0.7, 1.8), "path": [
		Vector2(212, 47), Vector2(210, 50), Vector2(206, 53), Vector2(201, 56), Vector2(194.6, 57.2)]},
	{"name": "Dorn", "major": true, "width": Vector2(1.0, 3.6), "path": [
		Vector2(236, 61), Vector2(236, 56), Vector2(235, 52), Vector2(234, 47), Vector2(232.5, 43), Vector2(232, 40.5),
		Vector2(232.5, 38)]},
	{"name": "Hroth", "major": false, "width": Vector2(0.8, 2.0), "path": [
		Vector2(237, 64), Vector2(236, 67), Vector2(235, 70), Vector2(235, 73)]},
	{"name": "Aurun", "major": true, "width": Vector2(1.4, 4.6), "path": [
		Vector2(225, -1), Vector2(222, 4), Vector2(218, 9), Vector2(214, 14), Vector2(212, 19), Vector2(213, 24),
		Vector2(212, 28), Vector2(212, 31.5)]},
	{"name": "Ombre", "major": true, "width": Vector2(1.2, 4.6), "path": [
		Vector2(206, 6), Vector2(200, 3), Vector2(194, 1.5), Vector2(188, -0.5), Vector2(183, -2), Vector2(180, -4)]},
	{"name": "Veld", "major": false, "width": Vector2(0.8, 2.2), "path": [
		Vector2(232, -14), Vector2(226, -18), Vector2(220, -22), Vector2(214, -27), Vector2(208.5, -29.5)]},
	{"name": "Seren", "major": true, "width": Vector2(1.4, 5.0), "path": [
		Vector2(286, 38), Vector2(293, 37), Vector2(300, 37.5), Vector2(306, 36), Vector2(312, 35), Vector2(318, 34.5),
		Vector2(324, 34), Vector2(330, 33.5), Vector2(336, 33.5), Vector2(340, 33.3)]},
	{"name": "Huang", "major": true, "width": Vector2(1.2, 4.2), "path": [
		Vector2(296, 48), Vector2(303, 46.5), Vector2(310, 45.5), Vector2(317, 44), Vector2(323, 44.5), Vector2(328, 45),
		Vector2(333, 46)]},
	{"name": "Gath", "major": true, "width": Vector2(1.2, 4.2), "path": [
		Vector2(288, 28), Vector2(292, 24), Vector2(296, 21), Vector2(300, 18.5), Vector2(304, 16.5), Vector2(306.5, 15.5)]},
	{"name": "Vel", "major": false, "width": Vector2(0.8, 2.2), "path": [
		Vector2(296, 60), Vector2(302, 58), Vector2(304, 62), Vector2(306, 66), Vector2(308, 71.5)]},
	{"name": "Murrin", "major": false, "width": Vector2(0.6, 1.8), "path": [
		Vector2(336, -28), Vector2(330, -32), Vector2(324, -35), Vector2(318, -37.5), Vector2(315, -39)]},
]

# Political colors mark borders and settlement markers only; land keeps its natural colors.
const KINGDOMS: Array = [
	{"key": "aldermark", "name": "Aldermark", "color": Color(0.72, 0.16, 0.14), "label_at": Vector2(180, 51.5)},
	{"key": "hrothmark", "name": "Hrothmark", "color": Color(0.18, 0.38, 0.66), "label_at": Vector2(241, 57.5)},
	{"key": "carvel", "name": "Carvel", "color": Color(0.70, 0.22, 0.52), "label_at": Vector2(146, 51.5)},
	{"key": "kesh", "name": "Kesh", "color": Color(0.80, 0.56, 0.08), "label_at": Vector2(213, 17)},
	{"key": "seren", "name": "Seren", "color": Color(0.08, 0.52, 0.40), "label_at": Vector2(319, 41)},
	{"key": "varuna", "name": "Varuna", "color": Color(0.46, 0.30, 0.72), "label_at": Vector2(296, 14.5)},
	{"key": "brannoch", "name": "Brannoch", "color": Color(0.88, 0.45, 0.10), "label_at": Vector2(93, 51)},
]

# Regions are the selectable unit of the world map and the bridge to the regional map.
# Each grows outward from its seed over land; mountains and rivers make costly crossings,
# so region and kingdom borders settle along ranges and rivers.
# "owner" is the controlling kingdom key ("" when unheld); "claims" lists kingdoms
# that claim the region without holding it.
const REGIONS: Array = [
	# Heartland
	{"name": "Varenne Coast", "at": Vector2(155, 45.5), "owner": "aldermark"},
	{"name": "Saelle Vale", "at": Vector2(168, 47.5), "owner": "aldermark"},
	{"name": "Highmoor", "at": Vector2(164, 54.5), "owner": "aldermark"},
	{"name": "Mirrormere", "at": Vector2(180, 56.5), "owner": "aldermark"},
	{"name": "Northfold", "at": Vector2(184, 63), "owner": "aldermark"},
	{"name": "Wendmark", "at": Vector2(195, 58.5), "owner": "aldermark"},
	{"name": "Crown Foothills", "at": Vector2(190, 44), "owner": "aldermark"},
	{"name": "Southern Reach", "at": Vector2(178, 40), "owner": "aldermark"},
	{"name": "Tarrow Plain", "at": Vector2(207, 51.5), "owner": "aldermark"},
	{"name": "Darkwood", "at": Vector2(215, 54), "owner": "aldermark"},
	{"name": "Avenna", "at": Vector2(205, 37), "owner": "aldermark"},
	{"name": "Crownspine Heights", "at": Vector2(202, 46), "owner": ""},
	{"name": "Skarnheim", "at": Vector2(173, 67), "owner": ""},
	{"name": "Frostmarch", "at": Vector2(192, 70), "owner": "", "claims": ["aldermark"]},
	{"name": "Taigard", "at": Vector2(209, 67), "owner": ""},
	{"name": "The Debatable Fells", "at": Vector2(222, 57), "owner": "", "claims": ["aldermark", "hrothmark"]},
	{"name": "Hrothvatn", "at": Vector2(239, 62), "owner": "hrothmark"},
	{"name": "Dornmark", "at": Vector2(236, 53), "owner": "hrothmark"},
	{"name": "Lower Dorn", "at": Vector2(233, 45), "owner": "hrothmark"},
	{"name": "Eastern Fells", "at": Vector2(248, 58), "owner": "hrothmark"},
	{"name": "Kolvik Coast", "at": Vector2(236, 69.5), "owner": "hrothmark"},
	{"name": "Bleakshore", "at": Vector2(250, 68), "owner": ""},
	{"name": "Graswold Steppe", "at": Vector2(247, 47), "owner": ""},
	{"name": "Tessaly", "at": Vector2(227, 37.5), "owner": ""},
	{"name": "Carvel", "at": Vector2(144, 50.5), "owner": "carvel"},
	{"name": "Westerholt", "at": Vector2(151.5, 58), "owner": "carvel"},
	{"name": "Isle of Wend", "at": Vector2(134, 55.5), "owner": "", "claims": ["carvel", "aldermark"]},
	{"name": "Svalgrim", "at": Vector2(207, 78), "owner": ""},
	# Southland
	{"name": "Aurun Delta", "at": Vector2(212, 28.5), "owner": "kesh"},
	{"name": "Middle Aurun", "at": Vector2(213, 21), "owner": "kesh"},
	{"name": "Upper Aurun", "at": Vector2(217, 11), "owner": "kesh"},
	{"name": "Siwan Oases", "at": Vector2(224, 22), "owner": "", "claims": ["kesh", "aldermark"]},
	{"name": "Redfang Coast", "at": Vector2(166, 28), "owner": ""},
	{"name": "Western Erg", "at": Vector2(164, 17), "owner": ""},
	{"name": "Central Erg", "at": Vector2(189, 19), "owner": ""},
	{"name": "Eastern Erg", "at": Vector2(235, 22), "owner": ""},
	{"name": "Western Gulf", "at": Vector2(166, 6), "owner": ""},
	{"name": "Ombre Basin", "at": Vector2(190, 1), "owner": ""},
	{"name": "Kessel Highlands", "at": Vector2(229, 4), "owner": ""},
	{"name": "Horn of Sabre", "at": Vector2(250, 9), "owner": ""},
	{"name": "Sunwall Coast", "at": Vector2(241, -6), "owner": ""},
	{"name": "Southern Veld", "at": Vector2(223, -18), "owner": ""},
	{"name": "Dry Karoo", "at": Vector2(209, -21), "owner": ""},
	{"name": "Cape Lands", "at": Vector2(220, -31), "owner": ""},
	# Westreach
	{"name": "Brannoch", "at": Vector2(86, 47), "owner": "brannoch"},
	{"name": "Greywold", "at": Vector2(93, 55), "owner": "brannoch"},
	{"name": "Southmere", "at": Vector2(94, 38), "owner": "brannoch"},
	{"name": "Meander Plains", "at": Vector2(77, 47), "owner": "", "claims": ["brannoch"]},
	{"name": "Lake Callow", "at": Vector2(67, 55), "owner": ""},
	{"name": "Upper Meander", "at": Vector2(56, 47), "owner": ""},
	{"name": "Thornspine North", "at": Vector2(42, 57), "owner": ""},
	{"name": "Tall Pines", "at": Vector2(58, 63), "owner": ""},
	{"name": "Frostrun Barrens", "at": Vector2(78, 67), "owner": ""},
	{"name": "Western Shore", "at": Vector2(47, 40), "owner": ""},
	{"name": "Mesa Country", "at": Vector2(64, 32), "owner": ""},
	{"name": "Sunward Plains", "at": Vector2(82, 36), "owner": ""},
	{"name": "The Isthmus", "at": Vector2(80, 16), "owner": ""},
	{"name": "Verdance Basin", "at": Vector2(88, -2), "owner": ""},
	{"name": "Western Jungle", "at": Vector2(70, 2), "owner": ""},
	{"name": "Southern Pampas", "at": Vector2(84, -24), "owner": ""},
	{"name": "Thornspine South", "at": Vector2(70, -20), "owner": ""},
	{"name": "Cape Desolation", "at": Vector2(76, -38), "owner": ""},
	# Jade Reach
	{"name": "Seren Delta", "at": Vector2(334, 35), "owner": "seren"},
	{"name": "Middle Seren", "at": Vector2(319, 36), "owner": "seren"},
	{"name": "Upper Seren", "at": Vector2(304, 38.5), "owner": "seren"},
	{"name": "Huang Plain", "at": Vector2(316, 45.5), "owner": "seren"},
	{"name": "Gulf Coast", "at": Vector2(328, 49), "owner": "seren"},
	{"name": "Northern Seren", "at": Vector2(322, 57), "owner": "seren"},
	{"name": "Southern Hills", "at": Vector2(322, 26), "owner": "seren"},
	{"name": "Jadewall Marches", "at": Vector2(300, 52.5), "owner": "seren"},
	{"name": "Lohan Marches", "at": Vector2(308, 27), "owner": "", "claims": ["seren", "varuna"]},
	{"name": "Gath Valley", "at": Vector2(298, 20.5), "owner": "varuna"},
	{"name": "Upper Gath", "at": Vector2(291, 25.5), "owner": "varuna"},
	{"name": "Varuna South", "at": Vector2(296, 6), "owner": "varuna"},
	{"name": "Pearl Coast", "at": Vector2(302, 13), "owner": "varuna"},
	{"name": "Ghat Hills", "at": Vector2(289, 13), "owner": "varuna"},
	{"name": "Skyroof Plateau", "at": Vector2(284, 37), "owner": ""},
	{"name": "Dust Basin", "at": Vector2(285, 45), "owner": ""},
	{"name": "Bitterwind Steppe", "at": Vector2(270, 51), "owner": ""},
	{"name": "Strait Coast", "at": Vector2(267, 39), "owner": ""},
	{"name": "Sundown Coast", "at": Vector2(277, 24.5), "owner": ""},
	{"name": "Taiga of Vel", "at": Vector2(288, 62), "owner": ""},
	{"name": "Northern Tundra", "at": Vector2(310, 67), "owner": ""},
	{"name": "Far Cape", "at": Vector2(338, 59), "owner": ""},
	# Islands and far lands
	{"name": "Sammar", "at": Vector2(314, 5), "owner": "", "claims": ["seren", "varuna"]},
	{"name": "Ulo", "at": Vector2(328, -3), "owner": ""},
	{"name": "Tessel", "at": Vector2(340, 3), "owner": ""},
	{"name": "Long Kava", "at": Vector2(308, -12), "owner": ""},
	{"name": "Red Interior", "at": Vector2(318, -30), "owner": ""},
	{"name": "Eastern Austral", "at": Vector2(334, -31), "owner": ""},
	{"name": "Western Austral", "at": Vector2(302, -29), "owner": ""},
	{"name": "Greyholm", "at": Vector2(127, 70), "owner": ""},
	{"name": "Corran Isles", "at": Vector2(122, 39), "owner": ""},
	{"name": "Fell Isle", "at": Vector2(140, -47), "owner": ""},
	{"name": "White Shelf West", "at": Vector2(40, -76), "owner": ""},
	{"name": "White Shelf South", "at": Vector2(130, -76), "owner": ""},
	{"name": "White Shelf East", "at": Vector2(220, -76), "owner": ""},
	{"name": "White Shelf Far", "at": Vector2(310, -76), "owner": ""},
]

# Settlements: tier 1 village, 2 town, 3 city, 4 great city. "capital_of" marks a kingdom's
# seat of government, independent of size. Allegiance follows the region's controller.
const SETTLEMENTS: Array = [
	# Aldermark: the old, densely settled heartland. Its greatest city is a port, not the capital.
	{"name": "Varenne", "at": Vector2(152, 45), "tier": 4, "population": 62000, "port": true},
	{"name": "Highmoor", "at": Vector2(165, 54.5), "tier": 3, "population": 24000, "capital_of": "aldermark"},
	{"name": "Lisle", "at": Vector2(174, 48.6), "tier": 3, "population": 21000},
	{"name": "Avenna", "at": Vector2(205.5, 35.5), "tier": 3, "population": 26000, "port": true},
	{"name": "Wendford", "at": Vector2(194.2, 58), "tier": 3, "population": 18000},
	{"name": "Tarrow", "at": Vector2(208, 51.5), "tier": 3, "population": 16000},
	{"name": "Aubrin", "at": Vector2(161, 46.6), "tier": 2, "population": 7000},
	{"name": "Saltreach", "at": Vector2(180, 38.4), "tier": 2, "population": 8500, "port": true},
	{"name": "Pellam", "at": Vector2(190, 44), "tier": 2, "population": 6000},
	{"name": "Merrow", "at": Vector2(180.5, 57.4), "tier": 2, "population": 5200},
	{"name": "Fallowmere", "at": Vector2(186, 53), "tier": 2, "population": 3200},
	{"name": "Dunhallow", "at": Vector2(214, 53.5), "tier": 2, "population": 2800},
	{"name": "Elmstead", "at": Vector2(185, 63.5), "tier": 1, "population": 900},
	{"name": "Ravensgate", "at": Vector2(182, 60.5), "tier": 1, "population": 1100},
	{"name": "Coldwater", "at": Vector2(171, 52), "tier": 1, "population": 800},
	{"name": "Brightwell", "at": Vector2(158, 50.5), "tier": 1, "population": 1000},
	{"name": "Kettering", "at": Vector2(200, 55), "tier": 1, "population": 900},
	{"name": "Stonebridge", "at": Vector2(197, 44.5), "tier": 1, "population": 700},
	{"name": "Oakhurst", "at": Vector2(169, 44), "tier": 1, "population": 1000},
	{"name": "Pennick", "at": Vector2(188, 41.5), "tier": 1, "population": 1200, "port": true},
	{"name": "Greyfriars", "at": Vector2(157, 42.2), "tier": 1, "population": 900},
	# Carvel: a small maritime kingdom whose capital is only a town.
	{"name": "Sel Carvel", "at": Vector2(143, 50.5), "tier": 2, "population": 6500, "capital_of": "carvel", "port": true},
	{"name": "Holt", "at": Vector2(150.5, 57), "tier": 2, "population": 4200, "port": true},
	{"name": "Tidesend", "at": Vector2(145.5, 48), "tier": 1, "population": 900, "port": true},
	{"name": "Wendhaven", "at": Vector2(133.5, 55.5), "tier": 1, "population": 600, "port": true},
	# Hrothmark: a cold forest kingdom beyond the Ironback.
	{"name": "Hrothgard", "at": Vector2(238, 62), "tier": 3, "population": 17000, "capital_of": "hrothmark"},
	{"name": "Dornburg", "at": Vector2(235.3, 52), "tier": 3, "population": 14000},
	{"name": "Dornmouth", "at": Vector2(232.3, 41.5), "tier": 2, "population": 7500, "port": true},
	{"name": "Kolvik", "at": Vector2(235, 70.5), "tier": 2, "population": 3800, "port": true},
	{"name": "Varn", "at": Vector2(229.5, 57.5), "tier": 1, "population": 700},
	{"name": "Eastmere", "at": Vector2(247, 58), "tier": 1, "population": 900},
	{"name": "Skelby", "at": Vector2(239, 47), "tier": 1, "population": 800},
	{"name": "Ostholm", "at": Vector2(244, 66), "tier": 1, "population": 600},
	# Heartland independents and frontier
	{"name": "Myra", "at": Vector2(227, 37), "tier": 3, "population": 19000, "port": true},
	{"name": "Fellgate", "at": Vector2(221.5, 56), "tier": 1, "population": 1500},
	{"name": "Wendmouth", "at": Vector2(190, 71.5), "tier": 1, "population": 900, "port": true},
	{"name": "Khazad Post", "at": Vector2(251.5, 46), "tier": 1, "population": 500},
	{"name": "Skarnwick", "at": Vector2(174, 68), "tier": 1, "population": 400},
	{"name": "Pinehold", "at": Vector2(208, 66), "tier": 1, "population": 350},
	# Kesh: an old river civilization strung along the Aurun.
	{"name": "Keshar", "at": Vector2(212.3, 29.4), "tier": 4, "population": 74000, "capital_of": "kesh", "port": true},
	{"name": "Tamesh", "at": Vector2(212.5, 20), "tier": 3, "population": 22000},
	{"name": "Nehet", "at": Vector2(213, 25), "tier": 2, "population": 5200},
	{"name": "Abydar", "at": Vector2(213.2, 16), "tier": 2, "population": 4800},
	{"name": "Sabu", "at": Vector2(217.5, 10), "tier": 2, "population": 6000},
	{"name": "Ruma", "at": Vector2(210.5, 27.5), "tier": 1, "population": 1500},
	{"name": "Iru", "at": Vector2(211.3, 22.5), "tier": 1, "population": 1300},
	{"name": "Shedu", "at": Vector2(215.5, 12), "tier": 1, "population": 1200},
	{"name": "Siwa Wells", "at": Vector2(224, 23), "tier": 1, "population": 1100},
	# Southland independents and frontier
	{"name": "Tazmir", "at": Vector2(165, 29.5), "tier": 2, "population": 4500, "port": true},
	{"name": "Oudra", "at": Vector2(172, 29), "tier": 1, "population": 900},
	{"name": "Port Ubari", "at": Vector2(162, 4.5), "tier": 1, "population": 1200, "port": true},
	{"name": "Ombe", "at": Vector2(190, 0), "tier": 1, "population": 700},
	{"name": "Amhara Kess", "at": Vector2(229, 5), "tier": 2, "population": 3800},
	{"name": "Debra", "at": Vector2(232, -1), "tier": 1, "population": 900},
	{"name": "Zanj", "at": Vector2(243.5, -8), "tier": 2, "population": 3000, "port": true},
	{"name": "Sabre Point", "at": Vector2(252, 10), "tier": 1, "population": 1000, "port": true},
	{"name": "Veld Kraal", "at": Vector2(224, -17), "tier": 1, "population": 500},
	{"name": "Capewater", "at": Vector2(219, -33.5), "tier": 1, "population": 800, "port": true},
	# Brannoch: a young colonial kingdom holding one gulf of a wild continent.
	{"name": "Port Brannoch", "at": Vector2(88.6, 45.5), "tier": 2, "population": 7200, "capital_of": "brannoch", "port": true},
	{"name": "Fennick", "at": Vector2(92, 55), "tier": 1, "population": 1400},
	{"name": "Southmere", "at": Vector2(96, 39), "tier": 1, "population": 1100, "port": true},
	{"name": "Callow Ford", "at": Vector2(80, 47.5), "tier": 1, "population": 600},
	{"name": "Hightrap", "at": Vector2(66, 56), "tier": 1, "population": 250},
	{"name": "Isthmus Landing", "at": Vector2(82, 14), "tier": 1, "population": 400, "port": true},
	# Seren: the most populous kingdom, on two great river plains.
	{"name": "Jinmar", "at": Vector2(318.5, 34.8), "tier": 4, "population": 91000, "capital_of": "seren"},
	{"name": "Serenhai", "at": Vector2(337, 33.8), "tier": 4, "population": 64000, "port": true},
	{"name": "Lohan", "at": Vector2(302, 37.2), "tier": 3, "population": 28000},
	{"name": "Tsur", "at": Vector2(317, 44.3), "tier": 3, "population": 23000},
	{"name": "Haldun", "at": Vector2(331, 46.3), "tier": 3, "population": 19000, "port": true},
	{"name": "Weiyan", "at": Vector2(326, 34.2), "tier": 2, "population": 9000},
	{"name": "Pemba", "at": Vector2(321, 26.5), "tier": 2, "population": 6500},
	{"name": "Anshar", "at": Vector2(327, 24.5), "tier": 2, "population": 8000, "port": true},
	{"name": "Kuro", "at": Vector2(310, 45.6), "tier": 2, "population": 5500},
	{"name": "Northgate", "at": Vector2(300, 52), "tier": 2, "population": 4000},
	{"name": "Hsien", "at": Vector2(324, 55), "tier": 1, "population": 1400},
	{"name": "Lanxi", "at": Vector2(308, 35.8), "tier": 1, "population": 1600},
	{"name": "Dao", "at": Vector2(314, 40), "tier": 1, "population": 1400},
	{"name": "Fen", "at": Vector2(328, 39), "tier": 1, "population": 1500},
	{"name": "Quan", "at": Vector2(323, 48), "tier": 1, "population": 1300},
	{"name": "Yulin", "at": Vector2(306, 41.5), "tier": 1, "population": 1200},
	{"name": "Baoshan", "at": Vector2(332, 29), "tier": 1, "population": 1500},
	# Varuna: a rich peninsula kingdom on the Gath.
	{"name": "Ashkel", "at": Vector2(299.5, 19.6), "tier": 4, "population": 52000, "capital_of": "varuna"},
	{"name": "Teshar", "at": Vector2(292, 24.5), "tier": 3, "population": 18000},
	{"name": "Merrin", "at": Vector2(303, 14.5), "tier": 2, "population": 8500, "port": true},
	{"name": "Kovalam", "at": Vector2(297.5, 4.5), "tier": 2, "population": 5000, "port": true},
	{"name": "Sindh", "at": Vector2(295, 15.5), "tier": 1, "population": 1500},
	{"name": "Palan", "at": Vector2(293.5, 9), "tier": 1, "population": 1300},
	{"name": "Nilgar", "at": Vector2(289.5, 12), "tier": 1, "population": 1100},
	{"name": "Marchgate", "at": Vector2(307, 27.5), "tier": 1, "population": 1400},
	# Jade Reach frontier and the islands
	{"name": "Strait Post", "at": Vector2(264.5, 40), "tier": 1, "population": 500, "port": true},
	{"name": "Lhar", "at": Vector2(284, 38.5), "tier": 1, "population": 400},
	{"name": "Kum Oasis", "at": Vector2(287, 44), "tier": 1, "population": 300},
	{"name": "Port Sammar", "at": Vector2(314, 5.5), "tier": 2, "population": 3500, "port": true},
	{"name": "Ulo Landing", "at": Vector2(327, -2), "tier": 1, "population": 700, "port": true},
	{"name": "Kava", "at": Vector2(305, -11), "tier": 1, "population": 500, "port": true},
	{"name": "Greyharbor", "at": Vector2(123, 63.5), "tier": 1, "population": 300, "port": true},
	{"name": "Corran", "at": Vector2(122, 39), "tier": 1, "population": 600, "port": true},
]

# [from, to, class]: 2 major route, 1 regional road, 0 local road.
# Major routes are routed first; later roads prefer existing roadbed, so networks merge.
const ROADS: Array = [
	# Major routes
	["Sel Carvel", "Varenne", 2],
	["Varenne", "Aubrin", 2],
	["Aubrin", "Lisle", 2],
	["Lisle", "Highmoor", 2],
	["Lisle", "Fallowmere", 2],
	["Fallowmere", "Wendford", 2],
	["Wendford", "Tarrow", 2],
	["Tarrow", "Dunhallow", 2],
	["Dunhallow", "Fellgate", 2],
	["Fellgate", "Varn", 2],
	["Varn", "Dornburg", 2],
	["Dornburg", "Hrothgard", 2],
	["Dornburg", "Dornmouth", 2],
	["Tarrow", "Avenna", 2],
	["Keshar", "Nehet", 2],
	["Nehet", "Tamesh", 2],
	["Tamesh", "Abydar", 2],
	["Abydar", "Sabu", 2],
	["Serenhai", "Weiyan", 2],
	["Weiyan", "Jinmar", 2],
	["Jinmar", "Lanxi", 2],
	["Lanxi", "Lohan", 2],
	["Jinmar", "Dao", 2],
	["Dao", "Tsur", 2],
	["Tsur", "Quan", 2],
	["Quan", "Haldun", 2],
	["Lohan", "Marchgate", 2],
	["Marchgate", "Teshar", 2],
	["Teshar", "Ashkel", 2],
	["Ashkel", "Merrin", 2],
	# Regional roads
	["Holt", "Highmoor", 1],
	["Sel Carvel", "Holt", 1],
	["Lisle", "Pellam", 1],
	["Pellam", "Saltreach", 1],
	["Merrow", "Fallowmere", 1],
	["Wendford", "Wendmouth", 1],
	["Hrothgard", "Kolvik", 1],
	["Dornburg", "Skelby", 1],
	["Skelby", "Khazad Post", 1],
	["Dornmouth", "Myra", 1],
	["Tamesh", "Siwa Wells", 1],
	["Sabu", "Amhara Kess", 1],
	["Keshar", "Oudra", 1],
	["Oudra", "Tazmir", 1],
	["Zanj", "Debra", 1],
	["Port Brannoch", "Fennick", 1],
	["Port Brannoch", "Southmere", 1],
	["Tsur", "Kuro", 1],
	["Kuro", "Lohan", 1],
	["Lohan", "Northgate", 1],
	["Jinmar", "Pemba", 1],
	["Pemba", "Anshar", 1],
	["Haldun", "Hsien", 1],
	["Merrin", "Kovalam", 1],
	["Strait Post", "Kum Oasis", 1],
	["Kum Oasis", "Lohan", 1],
	# Local roads
	["Highmoor", "Brightwell", 0],
	["Highmoor", "Coldwater", 0],
	["Lisle", "Oakhurst", 0],
	["Pellam", "Stonebridge", 0],
	["Saltreach", "Pennick", 0],
	["Merrow", "Ravensgate", 0],
	["Ravensgate", "Elmstead", 0],
	["Wendford", "Kettering", 0],
	["Varenne", "Greyfriars", 0],
	["Sel Carvel", "Tidesend", 0],
	["Hrothgard", "Ostholm", 0],
	["Dornburg", "Eastmere", 0],
	["Ravensgate", "Skarnwick", 0],
	["Kettering", "Pinehold", 0],
	["Keshar", "Ruma", 0],
	["Tamesh", "Iru", 0],
	["Sabu", "Shedu", 0],
	["Amhara Kess", "Debra", 0],
	["Port Brannoch", "Callow Ford", 0],
	["Callow Ford", "Hightrap", 0],
	["Serenhai", "Baoshan", 0],
	["Weiyan", "Fen", 0],
	["Lohan", "Yulin", 0],
	["Ashkel", "Sindh", 0],
	["Sindh", "Palan", 0],
	["Palan", "Kovalam", 0],
	["Teshar", "Nilgar", 0],
	["Lohan", "Lhar", 0],
]

const GEO_LABELS: Array = [
	{"text": "The Western Ocean", "kind": "ocean", "at": Vector2(8, 22)},
	{"text": "The Middle Ocean", "kind": "ocean", "at": Vector2(124, 12)},
	{"text": "The Southern Ocean", "kind": "ocean", "at": Vector2(178, -50)},
	{"text": "The Austral Sea", "kind": "ocean", "at": Vector2(262, -38)},
	{"text": "The Frozen Sea", "kind": "ocean", "at": Vector2(240, 80)},
	{"text": "The Eastern Sea", "kind": "sea", "at": Vector2(263, 2)},
	{"text": "The Amber Sea", "kind": "sea", "at": Vector2(190, 35)},
	{"text": "Gulf of Haldun", "kind": "sea", "at": Vector2(338, 45)},
	{"text": "Gulf of Brannoch", "kind": "sea", "at": Vector2(95.5, 45.5)},
	{"text": "Ghat Sea", "kind": "sea", "at": Vector2(285, 4)},
	{"text": "Westreach", "kind": "continent", "at": Vector2(72, 58)},
	{"text": "The Heartland", "kind": "continent", "at": Vector2(204, 63)},
	{"text": "Southland", "kind": "continent", "at": Vector2(198, -14)},
	{"text": "Jade Reach", "kind": "continent", "at": Vector2(302, 63)},
	{"text": "Austral", "kind": "continent", "at": Vector2(318, -34)},
	{"text": "The Thornspine", "kind": "landform", "at": Vector2(46.5, 44), "angle": -62.0},
	{"text": "The Crownspine", "kind": "landform", "at": Vector2(200, 48.8), "angle": -3.0},
	{"text": "The Ironback", "kind": "landform", "at": Vector2(224.5, 64), "angle": -82.0},
	{"text": "The Skyroof", "kind": "landform", "at": Vector2(285, 31.2), "angle": 0.0},
	{"text": "The Sunwall", "kind": "landform", "at": Vector2(233.5, 3), "angle": -72.0},
	{"text": "The Dragonback", "kind": "landform", "at": Vector2(234, -23), "angle": 55.0},
	{"text": "Jadewall", "kind": "landform", "at": Vector2(300, 55.6), "angle": -12.0},
	{"text": "The Ashen Erg", "kind": "landform", "at": Vector2(186, 22)},
	{"text": "The Dust Sea", "kind": "landform", "at": Vector2(282, 46.5)},
	{"text": "The Red Heart", "kind": "landform", "at": Vector2(318, -27)},
	{"text": "The White Shelf", "kind": "landform", "at": Vector2(180, -80)},
]

static func get_definition() -> Dictionary:
	return {
		"world_size": WORLD_SIZE,
		"terrain_size": TERRAIN_SIZE,
		"political_size": POLITICAL_SIZE,
		"coastline_noise_seed": COASTLINE_NOISE_SEED,
		"landmasses": LANDMASSES,
		"lakes": LAKES,
		"mountain_ranges": MOUNTAIN_RANGES,
		"highlands": HIGHLANDS,
		"moisture_zones": MOISTURE_ZONES,
		"forest_zones": FOREST_ZONES,
		"rivers": RIVERS,
		"kingdoms": KINGDOMS,
		"regions": REGIONS,
		"settlements": SETTLEMENTS,
		"roads": ROADS,
		"geo_labels": GEO_LABELS,
	}

static func build() -> WorldMapData:
	return WorldFieldBuilder.build(get_definition())
