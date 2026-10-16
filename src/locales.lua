local en={
    name='Interaction Filters',primary='Block ground primary pickups',
    team_support='Block teammates\' support weapons',field_support='Block field support weapons',
    sample_bottle='Block dropped sample bottles',sample='Block loose samples',info='Block scenery information',
    primary_description='Only your Helldiver ignores ground primary weapons. On by default. APPLY changes.',
    team_support_description='Blocks support weapons originally called in by a teammate, regardless of who carried them later. Your own call-ins remain pickable. Off by default.',
    field_support_description='Blocks support weapons originally placed on the map, regardless of who carried them later. Your own call-ins remain pickable. Off by default.',
    sample_bottle_description='Blocks dropped sample containers for your Helldiver. Off by default.',
    sample_description='Blocks loose common, rare and super samples for your Helldiver. Off by default.',
    info_description='Blocks background-story inspection interactions, such as vending machines, tools and forklifts. Does not block mission terminals or vehicle seats. Off by default.',
}
local zh={
    name='交互过滤',primary='禁止捡起地面主武器',
    team_support='禁止捡起队友的支援武器',field_support='禁止捡起野生支援武器',
    sample_bottle='禁止拾取样本瓶',sample='禁止拾取样本',info='禁止场景信息交互',
    primary_description='仅你的潜兵忽略地面主武器。默认开启，修改后点击“应用”。',
    team_support_description='按召唤来源区分：队友召唤的支援武器即使被你捡起再丢下仍归队友。本人召唤的武器仍可捡回。默认关闭。',
    field_support_description='按来源区分：地图原生放置的支援武器，即使被玩家拿过再丢下仍归野生。本人召唤的武器仍可捡回。默认关闭。',
    sample_bottle_description='禁止你的潜兵拾取掉落的样本容器。默认关闭。',
    sample_description='禁止你的潜兵拾取地面上的普通、稀有及超级样本。默认关闭。',
    info_description='禁止按交互键查看背景信息的场景交互，例如自动售货机、工具、叉车。不禁止任务终端或载具座位。默认关闭。',
}
return {english={mod='primary_pickup_blocker',language='en',strings=en},
    bundled={['zh-Hans']={mod='primary_pickup_blocker',language='zh-Hans',strings=zh}}}
