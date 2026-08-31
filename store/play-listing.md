# Google Play listing

Paste into the Play Console. Nothing here is read by the game or the export;
Play's listing fields have no counterpart in `project.godot`.

The app label under the icon is `config/name` in `project.godot` and stays
"Cat vs Bugs". It is a different field from the listing title below, and it
truncates at about twelve characters on a home screen, so the keyword version
would render as "Cat vs Bug...".

## Promo video

```
https://youtube.com/watch?v=IErxMtCPEUI
```

Unlisted, silent, eight seconds, with the title read over the end. Play takes
a link rather than a file and will not show a video with ads on it. Recorded
with `store/trailer.mp4` still in the repo, so it can be re-cut and re-uploaded
without rebuilding the run.

## Title (30 char limit)

```
Cat vs Bugs: Kids Cat Game
```

26 characters. "Cat" alone loses to Talking Tom and the rest of the category;
"cat" plus "bugs" is the pair nothing else in the top results has.

## Short description (80 char limit)

```
Be a cat. Zap the bugs. Buy silly hats with cookies. A game for little kids.
```

75 characters.

## Full description

Play indexes this text, so the terms a parent searches repeat in ordinary
sentences rather than being varied for style.

```
Cat vs Bugs is a cat game for kids.

You are the cat. The bugs come to you. Grubs, beetles, snails, wasps,
slime and spiders crawl in from every side, and your toys fire
themselves, so the only thing a child has to do is walk the cat out of
the way.

One finger. That is the whole control scheme. There is nothing to read,
nothing to type and no buttons to learn, so a kid can pick this cat game
up and play it on their own.

A CAT GAME WITH NO LOSING

Nobody loses this game. When the bugs finally catch the cat, the game
counts up how many bugs the cat squished and shows the number. Then you
play again. No defeat screen, no scolding, no starting over from the
beginning.

BUGS, TOYS AND COOKIES

Squish bugs and the cat picks up gems. Gems bring new toys: a paw swipe,
a yarn ball, a purr ring, a milk puddle that slows the bugs down, and a
shoal of fish that spins around the cat. Ten toys in all, and every one
of them fires on its own.

Squished bugs drop cookies. Cookies buy hats. There is a party hat, a
big bow, a cool cap and a crown, and the cat wears whichever hat your
child picks.

FIVE CATS, THREE PLACES

Pick Cookie, Minty, Berry, Choccy or Lion. Every cat is free and every
cat starts with a different toy. Then play the garden, the beach or the
arctic. All three places are free from the start, and all three play the
same, so choosing the one a child likes the look of never makes the game
harder.

A KIDS GAME FOR AGES 4 TO 12

Runs last ten minutes. The game saves cookies, cats and hats between
runs, so a child who closes the app keeps everything.

No ads. No in-app purchases. No sign-in, and nothing to buy with real
money. The cookies are earned by playing.

Cat vs Bugs is a free kids game for ages 4 to 12. More kinds of bug
arrive as the ten minutes run down, and a big bug turns up three times a
run, so there is something in it for an older kid while the controls
stay simple enough for the youngest.
```

## Data Safety form

No data collected and no data shared. The save is local: `user://save.json`,
or `localStorage` on the web build. There is no ad SDK, no in-app purchase, no
analytics, no HTTP client and no Android permission requested. Checked against
`scripts/`, `project.godot` and `export_presets.cfg`.

## What the copy claims, and where it is true

Every number and name below was read out of the source rather than remembered.
Retuning is expected here, so re-check this table before a listing update.

| Claim | Source |
| --- | --- |
| Eight kinds of bug, by name | `tuning.gd` `ENEMIES` |
| Ten toys | `tuning.gd` `WEAPONS` |
| Party Hat, Big Bow, Cool Cap, Crown | `tuning.gd` `HATS` |
| Five cats, free, one weapon each | `tuning.gd` `CATS` |
| Garden, Beach, Arctic, all free | `tuning.gd` `MAPS` |
| Ten minute runs | `tuning.gd` `RUN_SECONDS` |
| A big bug three times a run | `tuning.gd` `BOSS_MINUTES` |

"A pair of antlers" was in a draft of this copy and is not a hat in the game.
