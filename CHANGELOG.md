# Changelog

## [1.7.0] - 2026-11-16

### Changed
- The symbols page now stays up after . , ? and ! as it does after any other symbol, so ?!, ... and the like need no X in between. X, RT or sending goes back to letters.

### Fixed
- Holding LT erases word after word without the game's controller interface too; before, it erased only one word per press there.

## [1.6.0] - 2026-11-16

### Added
- Russian typing: the keyboard now guesses words in Russian, with all 33 letters including ё. Russian games use it by default, and Typing language in the settings picks it anywhere else. FlickChat's own text is in Russian on a Russian game too. Thanks to exdis for the Russian words and translation.

### Changed
- The keyboard under the first setup window shows guessed words in your typing language.
- Typing practice also offers words with accented letters.

### Fixed
- The first setup window shows the controller's button icons from the start, not numbers (Y as 4) until a button is pressed.

## [1.5.0] - 2026-11-16

### Added
- Keyboard shape: besides the wide keyboard, the guessed words can sit in a row of their own on top of the letters or below them, for a narrower, taller keyboard. Pick it under Keyboard shape in the settings, or with Y in the first setup window.
- Keyboard background: the dark backing behind the keyboard can be made solid, see-through or turned off while its border stays, in the settings or with LB and RB in the first setup window. The keyboard's size there is now on LT and RT.
- Text size: the letters and guessed words can be made larger or smaller apart from the keyboard's size, in the settings or with the d-pad's left and right in the first setup window.
- Button guide place: move the button guide with the left stick, from the settings.

### Changed
- Without the game's controller interface, the button guide sits over the chat window instead of on top of the keyboard, so it no longer covers the typing lesson.

### Fixed
- The button hints under chat now show in front of the action bars.

## [1.4.0] - 2026-11-14

### Added
- Spanish typing: the keyboard now guesses words in Spanish, with ñ and accents from plain flicks. Spanish and Latin American Spanish games use it by default, and Typing language in the settings picks it anywhere else. Words FlickChat learned from you on a Spanish game stay with Spanish.

## [1.3.0] - 2026-11-13

### Added
- Typing languages: the keyboard now guesses words in Portuguese, French, German and Italian as well as English. It follows your game's language, and Typing language in the settings picks another. Each language keeps the words it learned from you, and has its own first lesson and mature word filter.
- Accented letters: a word comes out with its accents from plain flicks (n, a, o gives não), and in exact letters a box also holds its accented letters.
- French and Italian words that join the next one (l', d', qu') are written onto it with no space.
- FlickChat's own text in Portuguese.
- A line in chat when someone in your guild or group has a newer FlickChat than yours, with where to update. It shows at each login until you have that version.

### Fixed
- RB's readings that are equally likely now come in the same order every time.

## [1.2.0] - 2026-11-13

### Added
- The keyboard now comes up for other text boxes too, not only chat: mail's To, Subject and message, the search boxes of your bags and bank, name boxes in dialogs. Put the game's cursor on the box and press Select. A keeps what you typed and B puts back what was there. Boxes that take only numbers open on the digits.
- The auction house can be searched with the controller: Select its search box, type, and A runs the search with the category and filters you picked.
- A line in chat when another addon has switched off Chat on the game's controller menu, naming that addon: the keyboard cannot open while it is.

### Changed
- The settings are a window of FlickChat's own, worked with the d-pad, A and B. Open it from the keyboard's wheel (Y, last page, Settings), from the game's Options on the AddOns tab, or with /flick options.
- While you type in another window's box, the keyboard, its button bar and its hints stand beside that window, never on it.
- FlickChat's name in chat and on its windows is in the blue of its icon.
- The setting that put chat on a controller button is gone: the game's controller mode never reads such a button. A button it had set is given back.
- The View and bumper marks on the chat tabs show only while chat is typed in, and a window standing over the chat covers them.

### Fixed
- An error from the game's own Status Text setting after FlickChat's options had been opened.
- In the auction house, the game's cursor now reaches Buy Now in the purchase dialog.
- A sent message is no longer kept as an unsent one.

## [1.1.0] - 2026-11-12

### Added
- Typing practice: a minute of words to type, with words a minute and accuracy, shown over the chat window. Nothing you type in it is sent. Start it from the options or with /flick practice.
- Move and resize the keyboard with the sticks: pick Move keyboard on the channel wheel, or use the options or /flick move.
- A window on first login to pick the keyboard's size, with a switch to the IM chat style for those who need it.
- Hold a word's d-pad button to forget that word, so a typo stops being suggested. The options bring forgotten words back.
- B keeps an unsent message for the next time you open chat. View clears the line.
- Quick phrases can be chained while A is held, and RT keeps them in the line so you can type on. An option stops them from sending by themselves.
- The lesson is new: a goal line, practice at chaining flicks, symbols, taking words off the d-pad, and it says what went wrong and how to undo it.

### Changed
- The keyboard sits off the typing line's top corner, so its hints stay clear of the button bar.
- A box lights as the stick reaches it.
- Dungeon tags and chat shorthand spelled by your flicks always get a d-pad slot.
- A swing straight across the stick that brushes a box on the way no longer spoils the word.
- On the symbols page, a held box's symbols show in blue on the other stick.
- The options are grouped in sections.

### Fixed
- An error that could stop the keyboard from drawing.
- The button bar no longer shifts when X changes its label.
- Interface action failed after pressing a FlickChat button in the options.

## [1.0.0] - 2026-11-12

First release.
