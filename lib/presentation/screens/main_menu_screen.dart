import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_flavor.dart';
import '../../data/progress_repository.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../widgets/achievement_popup.dart';
import '../widgets/coastal_ui.dart';
import '../widgets/game_ui.dart';
import 'achievements_screen.dart';
import 'booster_shop_screen.dart';
import 'collection_book_screen.dart';
import 'daily_challenges_screen.dart';
import 'endless_screen.dart';
import 'final_code_screen.dart';
import 'lucky_wheel_screen.dart';
import 'player_profile_screen.dart';
import 'qa_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'treasure_chests_screen.dart';
import 'world_selection_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  static const route = '/main-menu';

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with RouteAware {
  bool _dailyRewardAvailable = false;
  bool _dailySpinAvailable = false;
  bool _finalRewardUnlocked = false;
  int _coins = 0;
  bool _loginStreakPromptQueued = false;
  bool _loginStreakPromptShowing = false;
  bool _initialized = false;
  int _refreshGeneration = 0;
  Future<void> _popupQueue = Future<void>.value();
  PageRoute<dynamic>? _route;

  void _openProgressScreen(String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == null && route is PageRoute<dynamic>) {
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    if (!_initialized) {
      _initialized = true;
      unawaited(AppScope.of(context).audioService.startMenuMusic());
      _loadRewards();
    }
  }

  @override
  void didPush() {
    unawaited(AppScope.of(context).audioService.startMenuMusic());
  }

  @override
  void didPopNext() {
    unawaited(AppScope.of(context).audioService.startMenuMusic());
    _loadRewards();
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadRewards() async {
    final generation = ++_refreshGeneration;
    final repository = AppScope.of(context).progressRepository;
    final coins = await repository.coins();
    if (!mounted || generation != _refreshGeneration) return;
    final available = await repository.dailyRewardAvailable(DateTime.now());
    if (!mounted || generation != _refreshGeneration) return;
    final spinAvailable = await repository.dailySpinAvailable(DateTime.now());
    if (!mounted || generation != _refreshGeneration) return;
    final finalRewardUnlocked = await repository.finalRewardUnlocked();
    if (!mounted || generation != _refreshGeneration) return;
    final loginStreakStatus =
        await repository.dailyLoginStreakStatus(DateTime.now());
    if (!mounted || generation != _refreshGeneration) return;
    if (_coins != coins ||
        _dailyRewardAvailable != available ||
        _dailySpinAvailable != spinAvailable ||
        _finalRewardUnlocked != finalRewardUnlocked) {
      setState(() {
        _coins = coins;
        _dailyRewardAvailable = available;
        _dailySpinAvailable = spinAvailable;
        _finalRewardUnlocked = finalRewardUnlocked;
      });
    }
    _queueLoginStreakPopup(loginStreakStatus);
    // A previous refresh may still be showing a popup. Serialize consumption
    // without holding up newer coin/progress snapshots.
    final popupTask = _popupQueue.then<void>((_) async {
      if (!mounted) return;
      await showPendingAchievementPopups(
        context,
        repository,
        onPopup: AppScope.of(context).audioService.playAchievementUnlocked,
      );
    });
    _popupQueue = popupTask.catchError((Object _, StackTrace __) {});
    await popupTask;
  }

  Future<void> _claimDailyReward() async {
    final repository = AppScope.of(context).progressRepository;
    final updated = await repository.claimDailyReward(DateTime.now());
    if (!mounted) return;
    if (updated == null) {
      setState(() => _dailyRewardAvailable = false);
      return;
    }
    setState(() {
      _coins = updated;
      _dailyRewardAvailable = false;
    });
    await showDialog<void>(
      context: context,
      builder: (_) => GameDialogFrame(
        title: 'Daily Reward',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameRewardEmblem(icon: Icons.monetization_on_rounded),
            const SizedBox(height: GameSpacing.md),
            const Text('+100 coins', style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Claimed',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
              variant: GameButtonVariant.success,
            ),
          ],
        ),
      ),
    );
  }

  void _queueLoginStreakPopup(DailyLoginStreakStatus status) {
    if (!status.available || _loginStreakPromptQueued) return;
    _loginStreakPromptQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showLoginStreakPopup(status);
    });
  }

  Future<void> _showLoginStreakPopup(DailyLoginStreakStatus status) async {
    if (_loginStreakPromptShowing) return;
    _loginStreakPromptShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DailyLoginStreakDialog(
        status: status,
        onClaim: () async {
          final repository = AppScope.of(context).progressRepository;
          final claim = await repository.claimDailyLoginStreak(DateTime.now());
          if (!mounted) return;
          if (claim != null) {
            setState(() {
              _coins = claim.coins;
            });
          }
          Navigator.of(context).pop();
        },
      ),
    );
    _loginStreakPromptShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    CoastalButton action(String label, String art, VoidCallback? callback,
            {CoastalButtonTone tone = CoastalButtonTone.blue,
            bool primary = false}) =>
        CoastalButton(
            key: ValueKey('menu_action_$label'),
            label: label,
            art: art,
            onPressed: callback,
            tone: tone,
            compact: !primary,
            horizontal: primary,
            minHeight: 56);
    VoidCallback open(String route) =>
        () => Navigator.pushNamed(context, route);
    final kit = <CoastalButton>[
      action('Booster Shop', 'shop', open(BoosterShopScreen.route)),
      action('Profile', 'profile', open(PlayerProfileScreen.route)),
      action('Chests', 'chest', open(TreasureChestsScreen.route)),
      action(
          'Daily Challenges', 'challenge', open(DailyChallengesScreen.route)),
      action('Collection Book', 'collection', open(CollectionBookScreen.route)),
      action('Achievements', 'trophy', open(AchievementsScreen.route)),
      action('Statistics', 'statistics', open(StatisticsScreen.route)),
      action('Settings', 'settings',
          () => _openProgressScreen(SettingsScreen.route)),
      if (_finalRewardUnlocked)
        action('Final Reward', 'trophy', open(FinalCodeScreen.route)),
    ];
    return Scaffold(
        body: CoastalBackdrop(
            child: SafeArea(
                child: Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
            final primaryActions = _MenuActionRows(
                maxColumns: largeText ? 1 : 2,
                spacing: 8,
                actions: [
                  action('Adventure', 'play', open(WorldSelectionScreen.route),
                      tone: CoastalButtonTone.green, primary: true),
                  action('Endless Mode', 'endless', open(EndlessScreen.route),
                      tone: CoastalButtonTone.purple, primary: true),
                ]);
            final dailyActions = _MenuActionRows(maxColumns: 2, actions: [
              if (_dailyRewardAvailable)
                action('Claim Daily Reward', 'gift', _claimDailyReward),
              action(
                  _dailySpinAvailable ? 'Daily Spin' : 'Next Spin Tomorrow',
                  'wheel',
                  _dailySpinAvailable ? open(LuckyWheelScreen.route) : null),
            ]);
            final kitActions =
                _MenuActionRows(maxColumns: largeText ? 2 : 3, actions: kit);
            final contentWidth = constraints.maxWidth - 24;
            final panelWidth = contentWidth - 20;
            // The one-screen composition budgets one primary row, one daily
            // row and three kit rows. Wider font metrics can require more rows
            // even at text scale 1. Let that content scroll instead of forcing
            // it into the fixed-height Column with no remaining hero space.
            final fitPortrait = !largeText &&
                constraints.maxHeight >= 480 &&
                primaryActions.fitsRows(context, contentWidth, 1) &&
                dailyActions.fitsRows(context, panelWidth, 1) &&
                kitActions.fitsRows(context, panelWidth, 3);
            final shopShortcut = CoastalButton(
                key: const ValueKey('menu_shop_shortcut'),
                label: 'Shop',
                art: 'shop',
                compact: true,
                minHeight: 48,
                onPressed: open(BoosterShopScreen.route));
            final hero = Semantics(
                label: 'TrioTrek: Tile Adventure',
                image: true,
                child: LayoutBuilder(builder: (context, heroSpace) {
                  const logo = CoastalArt('logo', key: ValueKey('menu_logo'));
                  const cat =
                      CoastalArt('menu_cat', key: ValueKey('menu_mascot'));
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: heroSpace.maxHeight < 170
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Expanded(flex: 3, child: logo),
                                  Expanded(child: cat)
                                ])
                          : Column(children: [
                              Expanded(flex: 5, child: logo),
                              Expanded(flex: 4, child: cat)
                            ]));
                }));
            return SingleChildScrollView(
              key: const ValueKey('main_menu_scroll'),
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                  height: fitPortrait ? constraints.maxHeight - 24 : null,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      if (AppFlavorConfig.qaToolsEnabled && !largeText) ...[
                        SizedBox(
                            width: 82,
                            child: action('DEV QA Tools', 'tools',
                                () => _openProgressScreen(QaScreen.route))),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: GameBadge(
                                  gradient: GameGradients.darkBadge,
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CoastalArt('coin',
                                            width: 28, height: 28),
                                        const SizedBox(width: 5),
                                        Flexible(
                                            child: Text('$_coins',
                                                key: const ValueKey(
                                                    'menu_coins'),
                                                style: GameTextStyles.button
                                                    .copyWith(
                                                        color: Colors.white))),
                                      ])))),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: shopShortcut
                              .minimumReadableWidth(context)
                              .clamp(60.0, double.infinity)
                              .toDouble(),
                          child: shopShortcut),
                    ]),
                    if (AppFlavorConfig.qaToolsEnabled && largeText) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                          width: double.infinity,
                          child: action('DEV QA Tools', 'tools',
                              () => _openProgressScreen(QaScreen.route))),
                    ],
                    if (fitPortrait)
                      Expanded(child: hero)
                    else
                      SizedBox(height: 230, child: hero),
                    primaryActions,
                    const SizedBox(height: 8),
                    CoastalPanel(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      dailyActions,
                      const SizedBox(height: 6),
                      kitActions,
                    ])),
                    const SizedBox(height: 4),
                  ])),
            );
          })),
    ))));
  }
}

/// Preserve action order while giving long words enough width. A row gains
/// fewer columns when the scaled labels cannot share the available space.
class _MenuActionRows extends StatelessWidget {
  const _MenuActionRows(
      {required this.actions, required this.maxColumns, this.spacing = 6});
  final List<CoastalButton> actions;
  final int maxColumns;
  final double spacing;

  List<double> _minimums(BuildContext context) => [
        for (final action in actions) action.minimumReadableWidth(context),
      ];

  // Share the actual row-packing decision with the parent height policy.
  List<int> _rowEnds(List<double> minimums, double width) {
    final ends = <int>[];
    var start = 0;
    while (start < minimums.length) {
      var end = start + 1;
      var requiredWidth = minimums[start];
      while (end < minimums.length &&
          end - start < maxColumns &&
          requiredWidth + spacing + minimums[end] <= width) {
        requiredWidth += spacing + minimums[end];
        end++;
      }
      ends.add(end);
      start = end;
    }
    return ends;
  }

  bool fitsRows(BuildContext context, double width, int rows) =>
      _rowEnds(_minimums(context), width).length <= rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        final minimums = _minimums(context);
        final rows = <Widget>[];
        var start = 0;
        for (final end in _rowEnds(minimums, area.maxWidth)) {
          final count = end - start;
          final requiredWidth = minimums
              .sublist(start, end)
              .fold<double>(spacing * (count - 1), (sum, width) => sum + width);
          final surplus = (area.maxWidth - requiredWidth) / count;
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = start; i < end; i++) ...[
              if (i != start) SizedBox(width: spacing),
              SizedBox(
                  width: count == 1 ? area.maxWidth : minimums[i] + surplus,
                  child: actions[i]),
            ],
          ]));
          start = end;
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      });
}

class _DailyLoginStreakDialog extends StatelessWidget {
  const _DailyLoginStreakDialog({
    required this.status,
    required this.onClaim,
  });

  final DailyLoginStreakStatus status;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduceMotion ? 1 : 0.9, end: 1),
      duration: reduceMotion ? Duration.zero : GameDurations.normal,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Opacity(
          opacity: scale.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GameDialogFrame(
        title: 'Daily Login',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: GameGradients.badge,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: GameShadows.glow(GameColors.accentGold),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: GameSpacing.lg),
            Text('Day ${status.claimDay}', style: GameTextStyles.h2),
            const SizedBox(height: GameSpacing.sm),
            Text(
              '+${status.reward} coins',
              style: GameTextStyles.title.copyWith(
                color: GameColors.accentGold,
              ),
            ),
            const SizedBox(height: GameSpacing.lg),
            _StreakRewardRow(activeDay: status.claimDay),
            const SizedBox(height: GameSpacing.xl),
            GameButton(
              label: 'Claim',
              icon: Icons.card_giftcard_rounded,
              onPressed: () {
                onClaim();
              },
              variant: GameButtonVariant.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakRewardRow extends StatelessWidget {
  const _StreakRewardRow({required this.activeDay});

  final int activeDay;

  @override
  Widget build(BuildContext context) {
    const rewards = <int>[50, 75, 100, 125, 150, 200, 300];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 3 : 4;
      final width = (constraints.maxWidth - (columns - 1) * 4) / columns;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 6,
        children: [
          for (var index = 0; index < rewards.length; index++)
            SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: GameSpacing.xs),
                decoration: BoxDecoration(
                  gradient: index + 1 == activeDay
                      ? GameGradients.badge
                      : GameGradients.darkBadge,
                  borderRadius: GameRadius.smallRadius,
                  border: Border.all(color: Colors.white30, width: 1.5),
                  boxShadow: index + 1 == activeDay
                      ? GameShadows.glow(GameColors.accentGold)
                      : GameShadows.light(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'D${index + 1}',
                      style:
                          GameTextStyles.caption.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${rewards[index]}',
                      style:
                          GameTextStyles.caption.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}
