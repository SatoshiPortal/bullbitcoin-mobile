# Announcements

`AnnouncementsFeature.mount` builds the wallet home carousel. Dismissal data belongs to `announcements.sqlite` under the application's support `databases` directory. The foreground cutover copies historical IDs and timestamps before the admitted store can serve queries or accept writes. The old database is retained by the cutover coordinator.
