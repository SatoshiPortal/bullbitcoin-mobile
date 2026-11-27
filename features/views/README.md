# views

The screens of the multiple views of one installation: the list of the views a session opened, creation, renaming, deletion, the background-sync switch of the view in use, and the switcher.

The member sits behind a build gate. `ViewsFeature.mount(enabled: false)` contributes no route and builds empty widgets, which is the production state: `BULL_MULTI_VIEW` is not defined for release and reproducible builds. Nothing here decides access. The inventory in `secrets` decides which views a session opened, which view is in use and what each may reach; this member only asks it through the published capability and shows the answer.

Not in this member yet: setting or removing a PIN on a view, moving a seed between views, and the entries in Settings and on the home screen. They arrive with the activation.
