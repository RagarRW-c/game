import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/game_ui.dart';

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key});

  static const route = '/player-profile';

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<_ProfileData> _profileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profileFuture = _loadProfileData();
  }

  Future<_ProfileData> _loadProfileData() async {
    final repository = AppScope.of(context).progressRepository;
    final profile = await repository.playerProfile();
    final cosmetics = await repository.playerCosmetics();
    return _ProfileData(profile: profile, cosmetics: cosmetics);
  }

  Future<void> _selectFrame(String id) async {
    final selected =
        await AppScope.of(context).progressRepository.selectAvatarFrame(id);
    if (!mounted) return;
    if (!selected) {
      _showLockedMessage();
      return;
    }
    setState(() => _profileFuture = _loadProfileData());
  }

  Future<void> _selectBackground(String id) async {
    final selected = await AppScope.of(context)
        .progressRepository
        .selectProfileBackground(id);
    if (!mounted) return;
    if (!selected) {
      _showLockedMessage();
      return;
    }
    setState(() => _profileFuture = _loadProfileData());
  }

  Future<void> _selectBadge(String id) async {
    final selected =
        await AppScope.of(context).progressRepository.selectProfileBadge(id);
    if (!mounted) return;
    if (!selected) {
      _showLockedMessage();
      return;
    }
    setState(() => _profileFuture = _loadProfileData());
  }

  void _showLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cosmetic is locked')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final background =
              _backgroundById(data?.cosmetics.selectedBackground);
          return GameBackground(
            worldTheme: background?.theme,
            child: SafeArea(
              child: data == null
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          GameHeader(
                            title: 'Player Profile',
                            onBack: () => Navigator.of(context).maybePop(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: GameSpacing.lg,
                            ),
                            child: _ProfileHeader(data: data),
                          ),
                          const SizedBox(height: GameSpacing.md),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: GameSpacing.lg,
                            ),
                            child: _ProfileTabs(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _OverviewTab(profile: data.profile),
                                _CosmeticsTab(
                                  cosmetics: data.cosmetics,
                                  onSelectFrame: (id) {
                                    unawaited(_selectFrame(id));
                                  },
                                  onSelectBackground: (id) {
                                    unawaited(_selectBackground(id));
                                  },
                                  onSelectBadge: (id) {
                                    unawaited(_selectBadge(id));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.profile, required this.cosmetics});

  final PlayerProfileSummary profile;
  final PlayerCosmetics cosmetics;
}

class _ProfileTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.xs),
      shadow: GameShadows.light(),
      child: TabBar(
        indicator: BoxDecoration(
          gradient: GameGradients.primaryButton,
          borderRadius: GameRadius.largeRadius,
          boxShadow: GameShadows.light(GameColors.primaryBlue),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: GameColors.mutedInk,
        labelStyle: GameTextStyles.button,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Cosmetics'),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.profile});

  final PlayerProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GameSpacing.lg),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: GameSpacing.md,
          crossAxisSpacing: GameSpacing.md,
          childAspectRatio: 1.1,
          children: [
            _ProfileStatCard(
              icon: Icons.monetization_on_rounded,
              label: 'Coins',
              value: '${profile.coins}',
            ),
            _ProfileStatCard(
              icon: Icons.star_rounded,
              label: 'Total Stars',
              value: '${profile.totalStars}',
            ),
            _ProfileStatCard(
              icon: Icons.flag_rounded,
              label: 'Levels Completed',
              value: '${profile.levelsCompleted}',
            ),
            _ProfileStatCard(
              icon: Icons.emoji_events_rounded,
              label: 'Achievements',
              value:
                  '${profile.achievementsUnlocked}/${profile.achievementsTotal}',
            ),
            _ProfileStatCard(
              icon: Icons.collections_bookmark_rounded,
              label: 'Collection',
              value: '${profile.collectionUnlocked}/${profile.collectionTotal}',
            ),
            _ProfileStatCard(
              icon: Icons.casino_rounded,
              label: 'Wheel Spins',
              value: '${profile.luckyWheelSpins}',
            ),
            _ProfileStatCard(
              icon: Icons.local_fire_department_rounded,
              label: 'Daily Streak',
              value: '${profile.dailyStreak}',
            ),
            _ProfileStatCard(
              icon: Icons.auto_awesome_rounded,
              label: 'Boosters Used',
              value: '${profile.totalBoostersUsed}',
            ),
            _ProfileStatCard(
              icon: Icons.check_circle_rounded,
              label: 'Tiles Matched',
              value: '${profile.totalTilesMatched}',
            ),
            _ProfileStatCard(
              icon: Icons.all_inclusive_rounded,
              label: 'Best Endless',
              value: '${profile.bestEndlessScore}',
            ),
            _ProfileStatCard(
              icon: Icons.replay_rounded,
              label: 'Endless Runs',
              value: '${profile.totalEndlessRuns}',
            ),
            _ProfileStatCard(
              icon: Icons.grid_view_rounded,
              label: 'Endless Boards',
              value: '${profile.totalEndlessBoardsCleared}',
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.data});

  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final progress = (profile.totalXp % 500) / 500;
    final frame = _frameById(data.cosmetics.selectedFrame);
    final background = _backgroundById(data.cosmetics.selectedBackground);
    final badge = _badgeById(data.cosmetics.selectedBadge);
    return GameCard(
      gradient: background?.theme.boardGradient ?? GameGradients.panel,
      borderColor: frame?.theme.secondaryAccent ?? Colors.white,
      shadow: GameShadows.glow(
        frame?.theme.primaryAccent ?? GameColors.primaryBlueLight,
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: frame?.theme.trayGradient ?? GameGradients.badge,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: GameShadows.medium(
                frame?.theme.primaryAccent ?? GameColors.accentGold,
              ),
            ),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 46),
          ),
          const SizedBox(width: GameSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player Level ${profile.playerLevel}',
                  style: GameTextStyles.h2.copyWith(fontSize: 24),
                ),
                const SizedBox(height: GameSpacing.xs),
                Text('${profile.totalXp} XP', style: GameTextStyles.body),
                if (badge != null) ...[
                  const SizedBox(height: GameSpacing.xs),
                  GameBadge(
                    icon: badge.icon,
                    gradient: GameGradients.darkBadge,
                    child: Text(
                      badge.name,
                      style:
                          GameTextStyles.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ],
                const SizedBox(height: GameSpacing.sm),
                ClipRRect(
                  borderRadius: GameRadius.smallRadius,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: GameColors.borderBlue,
                    color: frame?.theme.primaryAccent ?? GameColors.accentGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticsTab extends StatelessWidget {
  const _CosmeticsTab({
    required this.cosmetics,
    required this.onSelectFrame,
    required this.onSelectBackground,
    required this.onSelectBadge,
  });

  final PlayerCosmetics cosmetics;
  final ValueChanged<String> onSelectFrame;
  final ValueChanged<String> onSelectBackground;
  final ValueChanged<String> onSelectBadge;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(GameSpacing.lg),
      children: [
        _CosmeticSection(
          title: 'Avatar Frames',
          children: [
            for (final item in _avatarFrames)
              _CosmeticCard(
                item: item,
                unlocked: cosmetics.frameUnlocked(item.id),
                selected: cosmetics.selectedFrame == item.id,
                onPressed: () => onSelectFrame(item.id),
              ),
          ],
        ),
        const SizedBox(height: GameSpacing.lg),
        _CosmeticSection(
          title: 'Profile Backgrounds',
          children: [
            for (final item in _profileBackgrounds)
              _CosmeticCard(
                item: item,
                unlocked: cosmetics.backgroundUnlocked(item.id),
                selected: cosmetics.selectedBackground == item.id,
                onPressed: () => onSelectBackground(item.id),
              ),
          ],
        ),
        const SizedBox(height: GameSpacing.lg),
        _CosmeticSection(
          title: 'Badges',
          children: [
            for (final item in _profileBadges)
              _CosmeticCard(
                item: item,
                unlocked: cosmetics.badgeUnlocked(item.id),
                selected: cosmetics.selectedBadge == item.id,
                onPressed: () => onSelectBadge(item.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _CosmeticSection extends StatelessWidget {
  const _CosmeticSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: GameSpacing.sm),
          child: Text(
            title,
            style: GameTextStyles.title.copyWith(fontSize: 20),
          ),
        ),
        const SizedBox(height: GameSpacing.sm),
        ...children,
      ],
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.item,
    required this.unlocked,
    required this.selected,
    required this.onPressed,
  });

  final _CosmeticDefinition item;
  final bool unlocked;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GameSpacing.md),
      child: GameCard(
        padding: const EdgeInsets.all(GameSpacing.md),
        gradient: unlocked ? item.theme.boardGradient : GameGradients.disabled,
        borderColor: selected ? GameColors.accentGold : Colors.white,
        shadow: selected
            ? GameShadows.glow(GameColors.accentGold)
            : GameShadows.medium(item.theme.primaryAccent),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: unlocked ? item.theme.trayGradient : null,
                color: unlocked ? null : GameColors.mutedInk,
                borderRadius: GameRadius.largeRadius,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: GameShadows.light(item.theme.primaryAccent),
              ),
              child: Icon(
                unlocked ? item.icon : Icons.lock_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: GameSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GameTextStyles.h2.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: GameSpacing.xs),
                  Text(
                    unlocked
                        ? selected
                            ? 'Selected'
                            : 'Unlocked'
                        : item.unlockCondition,
                    style: GameTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: GameSpacing.sm),
            SizedBox(
              width: 104,
              child: GameButton(
                label: selected ? 'Active' : 'Select',
                icon: selected
                    ? Icons.check_circle_rounded
                    : Icons.palette_rounded,
                onPressed: selected
                    ? () {}
                    : unlocked
                        ? onPressed
                        : null,
                variant: selected
                    ? GameButtonVariant.success
                    : GameButtonVariant.secondary,
                height: 46,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      padding: const EdgeInsets.all(GameSpacing.md),
      shadow: GameShadows.medium(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: GameColors.primaryBlue, size: 34),
          const SizedBox(height: GameSpacing.sm),
          Text(value, style: GameTextStyles.h2.copyWith(fontSize: 25)),
          const SizedBox(height: GameSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GameTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _CosmeticDefinition {
  const _CosmeticDefinition({
    required this.id,
    required this.name,
    required this.unlockCondition,
    required this.icon,
    required this.theme,
  });

  final String id;
  final String name;
  final String unlockCondition;
  final IconData icon;
  final WorldVisualTheme theme;
}

const _avatarFrames = <_CosmeticDefinition>[
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameGarden,
    name: 'Garden Frame',
    unlockCondition: 'Complete Garden World',
    icon: Icons.local_florist_rounded,
    theme: WorldThemes.garden,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameOcean,
    name: 'Ocean Frame',
    unlockCondition: 'Complete Ocean World',
    icon: Icons.water_rounded,
    theme: WorldThemes.ocean,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameCandy,
    name: 'Candy Frame',
    unlockCondition: 'Complete Candy World',
    icon: Icons.icecream_rounded,
    theme: WorldThemes.candy,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameSpace,
    name: 'Space Frame',
    unlockCondition: 'Complete Space World',
    icon: Icons.auto_awesome_rounded,
    theme: WorldThemes.space,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameDesert,
    name: 'Desert Frame',
    unlockCondition: 'Complete Desert World',
    icon: Icons.wb_sunny_rounded,
    theme: WorldThemes.desert,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameIce,
    name: 'Ice Frame',
    unlockCondition: 'Complete Ice World',
    icon: Icons.ac_unit_rounded,
    theme: WorldThemes.ice,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameJungle,
    name: 'Jungle Frame',
    unlockCondition: 'Complete Jungle World',
    icon: Icons.forest_rounded,
    theme: WorldThemes.jungle,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameVolcano,
    name: 'Volcano Frame',
    unlockCondition: 'Complete Volcano World',
    icon: Icons.local_fire_department_rounded,
    theme: WorldThemes.volcano,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameDream,
    name: 'Dream Frame',
    unlockCondition: 'Complete Dream World',
    icon: Icons.cloud_rounded,
    theme: WorldThemes.dream,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.avatarFrameCrystal,
    name: 'Crystal Frame',
    unlockCondition: 'Complete Crystal World',
    icon: Icons.diamond_rounded,
    theme: WorldThemes.crystal,
  ),
];

const _profileBackgrounds = <_CosmeticDefinition>[
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundGarden,
    name: 'Garden Theme',
    unlockCondition: 'Complete Garden World',
    icon: Icons.grass_rounded,
    theme: WorldThemes.garden,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundOcean,
    name: 'Ocean Theme',
    unlockCondition: 'Complete Ocean World',
    icon: Icons.waves_rounded,
    theme: WorldThemes.ocean,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundCandy,
    name: 'Candy Theme',
    unlockCondition: 'Complete Candy World',
    icon: Icons.cookie_rounded,
    theme: WorldThemes.candy,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundSpace,
    name: 'Space Theme',
    unlockCondition: 'Complete Space World',
    icon: Icons.public_rounded,
    theme: WorldThemes.space,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundDesert,
    name: 'Desert Theme',
    unlockCondition: 'Complete Desert World',
    icon: Icons.wb_sunny_rounded,
    theme: WorldThemes.desert,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundIce,
    name: 'Ice Theme',
    unlockCondition: 'Complete Ice World',
    icon: Icons.ac_unit_rounded,
    theme: WorldThemes.ice,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundJungle,
    name: 'Jungle Theme',
    unlockCondition: 'Complete Jungle World',
    icon: Icons.forest_rounded,
    theme: WorldThemes.jungle,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundVolcano,
    name: 'Volcano Theme',
    unlockCondition: 'Complete Volcano World',
    icon: Icons.local_fire_department_rounded,
    theme: WorldThemes.volcano,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundDream,
    name: 'Dream Theme',
    unlockCondition: 'Complete Dream World',
    icon: Icons.cloud_rounded,
    theme: WorldThemes.dream,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.profileBackgroundCrystal,
    name: 'Crystal Theme',
    unlockCondition: 'Complete Crystal World',
    icon: Icons.diamond_rounded,
    theme: WorldThemes.crystal,
  ),
];

const _profileBadges = <_CosmeticDefinition>[
  _CosmeticDefinition(
    id: ProgressRepository.badgeWorldConqueror,
    name: 'World Conqueror',
    unlockCondition: 'Complete all worlds',
    icon: Icons.emoji_events_rounded,
    theme: WorldThemes.space,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.badgeLuckyPlayer,
    name: 'Lucky Player',
    unlockCondition: 'Unlock Lucky Player achievement',
    icon: Icons.casino_rounded,
    theme: WorldThemes.ocean,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.badgeCollector,
    name: 'Collector',
    unlockCondition: 'Complete the Collection Book',
    icon: Icons.collections_bookmark_rounded,
    theme: WorldThemes.garden,
  ),
  _CosmeticDefinition(
    id: ProgressRepository.badgeThreeStarMaster,
    name: '3-Star Master',
    unlockCondition: 'Earn 3 stars on every level',
    icon: Icons.star_rounded,
    theme: WorldThemes.candy,
  ),
];

_CosmeticDefinition? _frameById(String? id) {
  return _definitionById(_avatarFrames, id);
}

_CosmeticDefinition? _backgroundById(String? id) {
  return _definitionById(_profileBackgrounds, id);
}

_CosmeticDefinition? _badgeById(String? id) {
  return _definitionById(_profileBadges, id);
}

_CosmeticDefinition? _definitionById(
  List<_CosmeticDefinition> definitions,
  String? id,
) {
  if (id == null) return null;
  for (final definition in definitions) {
    if (definition.id == id) return definition;
  }
  return null;
}
