import GRDB

enum SchemaMigrator {
    static func registerAll(into migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try createSessions(db)
            try createPhotos(db)
            try createSpecies(db)
            try createSpeciesFTS(db)
            try createPhotoAnalyses(db)
            try createBirdDetections(db)
            try createPhotoRatings(db)
            try createEdits(db)
            try createProjects(db)
        }
    }

    private static func createSessions(_ db: Database) throws {
        try db.create(table: "sessions") { t in
            t.primaryKey("id", .text)
            t.column("name", .text).notNull()
            t.column("location_name", .text)
            t.column("location_lat", .double)
            t.column("location_lon", .double)
            t.column("date_start", .double).notNull()
            t.column("date_end", .double).notNull()
            t.column("created_at", .double).notNull()
            t.column("color_hex", .text)
            t.column("icon_name", .text)
        }
    }

    private static func createPhotos(_ db: Database) throws {
        try db.create(table: "photos") { t in
            t.primaryKey("id", .text)
            t.column("session_id", .text).notNull()
                .references("sessions", onDelete: .cascade)
            t.column("file_bookmark", .blob).notNull()
            t.column("file_url_cached", .text).notNull()
            t.column("checksum", .text).notNull()
            t.column("file_size", .integer).notNull()
            t.column("format", .text).notNull()

            t.column("captured_at", .double).notNull()
            t.column("camera_make", .text)
            t.column("camera_model", .text)
            t.column("lens_model", .text)
            t.column("focal_length", .double)
            t.column("iso", .integer)
            t.column("shutter_denom", .integer)
            t.column("aperture", .double)
            t.column("gps_lat", .double)
            t.column("gps_lon", .double)
            t.column("image_width", .integer).notNull()
            t.column("image_height", .integer).notNull()

            t.column("status", .integer).notNull().defaults(to: 0)
            t.column("imported_at", .double).notNull()
            t.column("analyzed_at", .double)
        }
        try db.create(indexOn: "photos", columns: ["session_id", "captured_at"])
        try db.create(indexOn: "photos", columns: ["checksum"])
    }

    private static func createPhotoAnalyses(_ db: Database) throws {
        try db.create(table: "photo_analyses") { t in
            t.primaryKey("photo_id", .text)
                .references("photos", onDelete: .cascade)

            t.column("quality_overall", .double).notNull()
            t.column("quality_sharpness", .double).notNull()
            t.column("quality_exposure", .double).notNull()
            t.column("quality_eye_sharp", .double)
            t.column("quality_composition", .double)
            t.column("quality_percentile", .double).notNull()

            t.column("feature_print", .blob).notNull()
            t.column("scene_id", .text)
            t.column("is_scene_best", .integer).notNull().defaults(to: 0)
            t.column("analyzed_version", .integer).notNull()
        }
        try db.create(indexOn: "photo_analyses", columns: ["scene_id"])
    }

    private static func createBirdDetections(_ db: Database) throws {
        try db.create(table: "bird_detections") { t in
            t.primaryKey("id", .text)
            t.column("photo_id", .text).notNull()
                .references("photos", onDelete: .cascade)
            t.column("bbox_x", .double).notNull()
            t.column("bbox_y", .double).notNull()
            t.column("bbox_w", .double).notNull()
            t.column("bbox_h", .double).notNull()
            t.column("confidence", .double).notNull()

            t.column("species_id", .text)
                .references("species")
            t.column("species_confidence", .double)
            t.column("species_source", .text).notNull().defaults(to: "unknown")
        }
        try db.create(indexOn: "bird_detections", columns: ["photo_id"])
        try db.create(indexOn: "bird_detections", columns: ["species_id"])
    }

    private static func createSpecies(_ db: Database) throws {
        try db.create(table: "species") { t in
            t.primaryKey("id", .text)
            t.column("common_name_en", .text).notNull()
            t.column("common_name_zh", .text)
            t.column("scientific_name", .text).notNull()
            t.column("family", .text)
            t.column("family_zh", .text)
            t.column("order_name", .text)
        }
    }

    private static func createSpeciesFTS(_ db: Database) throws {
        try db.create(virtualTable: "species_fts", using: FTS5()) { t in
            t.synchronize(withTable: "species")
            t.tokenizer = .unicode61()
            t.column("common_name_en")
            t.column("common_name_zh")
            t.column("scientific_name")
        }
    }

    private static func createPhotoRatings(_ db: Database) throws {
        try db.create(table: "photo_ratings") { t in
            t.primaryKey("photo_id", .text)
                .references("photos", onDelete: .cascade)
            t.column("decision", .integer).notNull().defaults(to: 0)
            t.column("star", .integer).notNull().defaults(to: 0)
            t.column("color_label", .integer).notNull().defaults(to: 0)
            t.column("note", .text)
            t.column("rated_at", .double).notNull()
        }
    }

    private static func createEdits(_ db: Database) throws {
        try db.create(table: "edits") { t in
            t.primaryKey("id", .text)
            t.column("photo_id", .text).notNull()
                .references("photos", onDelete: .cascade)
            t.column("edit_json", .text).notNull()
            t.column("name", .text)
            t.column("created_at", .double).notNull()
            t.column("updated_at", .double).notNull()
            t.column("is_current", .integer).notNull().defaults(to: 0)
        }
        try db.create(indexOn: "edits", columns: ["photo_id", "is_current"])
    }

    private static func createProjects(_ db: Database) throws {
        try db.create(table: "projects") { t in
            t.primaryKey("id", .text)
            t.column("name", .text).notNull()
            t.column("created_at", .double).notNull()
        }
        try db.create(table: "project_photos") { t in
            t.column("project_id", .text).notNull()
                .references("projects", onDelete: .cascade)
            t.column("photo_id", .text).notNull()
                .references("photos", onDelete: .cascade)
            t.column("order_idx", .integer).notNull()
            t.primaryKey(["project_id", "photo_id"])
        }
        try db.create(indexOn: "project_photos", columns: ["project_id", "order_idx"])
    }
}
