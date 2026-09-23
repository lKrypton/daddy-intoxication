Locales = Locales or {}

Locales.en = {
    stage_1 = 'A pleasant warmth spreads through you.',
    stage_2 = 'The world is starting to spin.',
    stage_3 = 'Your head is spinning and your legs feel weak.',
    stage_4 = 'You are dangerously drunk. Everything is going dark...',

    recovery_used = 'You feel a little clearer.',
    recovery_sober = 'You feel completely sober again.',

    nausea_warning = 'Your stomach is turning! Try to hold it in!',
    nausea_resisted = 'You take a deep breath and settle your stomach.',
    vomited = 'You could not hold it in...',

    blackout_start = 'Your vision fades as you pass out...',
    blackout_wake = 'You slowly come to with a pounding headache.',

    cmd_setalcohol = 'Set a player\'s alcohol level',
    cmd_testnausea = 'Trigger a nausea wave (debug)',
    cmd_testvomit = 'Play the vomit sequence without changing alcohol (debug)',
    cmd_testblackout = 'Trigger a blackout (debug)',
    param_target = 'Player ID',
    param_amount = 'Alcohol points (0-100)',
    param_profile = 'Drink profile (optional)',

    invalid_player = 'Invalid or offline player.',
    invalid_profile = 'Unknown drink profile: %s',
    alcohol_set = 'Alcohol for player %s set to %s (%s).',
    test_triggered = 'Test triggered for player %s.',
}
