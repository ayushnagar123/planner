/*
* Copyright © 2019 Alain M. (https://github.com/alainm23/planner)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Alain M. <alain23@protonmail.com>
*/

public class Widgets.QuickFind : Gtk.Revealer {
    private Gtk.SearchEntry entry;
    private Gtk.ListBox listbox;

    public QuickFind () {
        transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        margin_top = 75;
        valign = Gtk.Align.START;
        halign = Gtk.Align.CENTER;
        reveal_child = false;
    }

    construct {
        entry = new Gtk.SearchEntry ();
        entry.margin = 9;
        entry.width_request = 350;
        entry.placeholder_text = _("Quick find");

        var quick_find_grid = new Gtk.Grid ();
        quick_find_grid.margin = 6;
        quick_find_grid.get_style_context ().add_class ("card");
        quick_find_grid.get_style_context ().add_class ("planner-card-radius");
        quick_find_grid.add (entry);

        listbox = new Gtk.ListBox ();
        listbox.expand = true;

        var search_scroll = new Gtk.ScrolledWindow (null, null);
        search_scroll.margin = 6;
        search_scroll.height_request = 250;
        search_scroll.expand = true;
        search_scroll.add (listbox);

        var search_grid = new Gtk.Grid ();
        search_grid.margin = 6;
        search_grid.get_style_context ().add_class ("card");
        search_grid.get_style_context ().add_class ("planner-card-radius");
        search_grid.orientation = Gtk.Orientation.VERTICAL;
        search_grid.add (search_scroll);

        var revealer = new Gtk.Revealer ();
        revealer.add (search_grid);
        revealer.reveal_child = false;

        var main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;

        main_grid.add (quick_find_grid);
        main_grid.add (revealer);

        add (main_grid);
        update_items ();

        listbox.row_activated.connect ((row) => {
            var item = row as Item;

            if (item.is_inbox) {
                Application.signals.go_action_page (0);
            } else if (item.is_today) {
                Application.signals.go_action_page (1);
            } else if (item.is_upcoming) {
                Application.signals.go_action_page (2);
            } else if (item.is_all_tasks) {
                Application.signals.go_action_page (3);
            } else if (item.is_completed) {
                Application.signals.go_action_page (4);
            } else if (item.is_project) {
                Application.signals.go_project_page (item.project_id);
            } else if (item.is_task) {
                Application.signals.go_task_page (item.task_id, item.project_id);
            }

            reveal_child = false;
            entry.text = "";
            listbox.unselect_all ();
        });

        listbox.set_filter_func ((row) => {
            var item = row as Item;

            if (entry.text.down () == _("all")) {
                return true;
            } else {
                return entry.text.down () in item.title.down ();
            }
        });

        entry.search_changed.connect (() => {
            if (entry.text != "") {
                revealer.reveal_child = true;
            } else {
                revealer.reveal_child = false;
            }

            listbox.invalidate_filter ();
        });

        entry.focus_out_event.connect (() => {
            if (entry.text == "") {
                reveal_child = false;
                listbox.unselect_all ();
            }

            return false;
        });

        this.key_release_event.connect ((key) => {
            if (key.keyval == 65307) {
                entry.text = "";
                reveal_child = false;
                listbox.unselect_all ();
            }

            return false;
        });

        Application.signals.on_signal_show_quick_find.connect (() => {
            if (reveal_child) {
                entry.text = "";
                reveal_child = false;
                listbox.unselect_all ();
            } else {
                reveal_child = true;
                entry.grab_focus ();
            }
        });

        Application.database.add_task_signal.connect (() => {
            var task = Application.database.get_last_task ();

            var row = new Item (task.content, "emblem-default-symbolic");
            row.is_task = true;
            row.task_id = task.id;
            row.project_id = task.project_id;

            listbox.add (row);

            listbox.show_all ();
        });

        Application.database.on_signal_remove_task.connect ((task) => {
            foreach (Gtk.Widget element in listbox.get_children ()) {
                var row = element as Item;

                if (row.is_task && row.task_id == task.id) {
                    GLib.Timeout.add (250, () => {
                        row.destroy ();
                        return GLib.Source.REMOVE;
                    });
                }
            }
        });

        Application.database.update_task_signal.connect ((task) => {
            foreach (Gtk.Widget element in listbox.get_children ()) {
                var row = element as Item;

                if (row.is_task && row.task_id == task.id) {
                    row.title = task.content;
                }
            }
        });

        Application.database.on_add_project_signal.connect (() => {
            var project = Application.database.get_last_project ();
            var row = new Item (project.name, "planner-startup-symbolic");
            row.is_project = true;
            row.project_id = project.id;

            listbox.add (row);

            listbox.show_all ();
        });

        Application.database.update_project_signal.connect ((project) => {
            foreach (Gtk.Widget element in listbox.get_children ()) {
                var row = element as Item;

                if (row.is_project && row.project_id == project.id) {
                    row.title = project.name;
                }
            }
        });

        Application.database.on_signal_remove_project.connect ((project) => {
            foreach (Gtk.Widget element in listbox.get_children ()) {
                var row = element as Item;

                if (row.is_project && row.project_id == project.id) {
                    GLib.Timeout.add (250, () => {
                        row.destroy ();
                        return GLib.Source.REMOVE;
                    });
                }
            }
        });
    }

    private void update_items () {
        // Tasks
        var all_tasks = new Gee.ArrayList<Objects.Task?> ();
        all_tasks = Application.database.get_all_search_tasks ();

        foreach (var task in all_tasks) {
            var row = new Item (task.content, "emblem-default-symbolic");
            row.is_task = true;
            row.task_id = task.id;
            row.project_id = task.project_id;

            listbox.add (row);
        }

        // Projects
        var all_projects = new Gee.ArrayList<Objects.Project?> ();
        all_projects= Application.database.get_all_projects ();

        foreach (var project in all_projects) {
            var row = new Item (project.name, "planner-startup-symbolic");
            row.is_project = true;
            row.project_id = project.id;

            listbox.add (row);
        }

        // Items
        var inbox_row = new Item (_("Inbox"), "mail-mailbox-symbolic");
        inbox_row.is_inbox = true;
        listbox.add (inbox_row);

        var today_row = new Item (_("Today"), "help-about-symbolic");
        today_row.is_today = true;
        listbox.add (today_row);

        var upcoming_row = new Item (_("Upcoming"), "x-office-calendar-symbolic");
        upcoming_row.is_upcoming = true;
        listbox.add (upcoming_row);

        var all_tasks_row = new Item (_("All Tasks"), "user-bookmarks-symbolic");
        all_tasks_row.is_all_tasks = true;
        listbox.add (all_tasks_row);

        var completed_tasks_row = new Item (_("Completed Tasks"), "process-completed-symbolic");
        completed_tasks_row.is_completed = true;
        listbox.add (completed_tasks_row);

        listbox.show_all ();
    }
}

public class Item : Gtk.ListBoxRow {

    public string title {
        get {
            return name_label.label;
        }
        set {
            name_label.label = value;
            tooltip_text = value;
        }
    }

    public string icon_name {
        owned get {
            return image.icon_name ?? "";
        }
        set {
            if (value != null && value != "") {
                image.gicon = new ThemedIcon (value);
                image.pixel_size = 16;
                image.no_show_all = false;
                image.show ();
            } else {
                image.no_show_all = true;
                image.hide ();
            }
        }
    }

    public Gtk.Label name_label;
    public Gtk.Image image;

    public bool is_inbox;
    public bool is_today;
    public bool is_upcoming;
    public bool is_project;
    public bool is_task;
    public bool is_all_tasks;
    public bool is_completed;

    public int project_id;
    public int task_id;

    public Item (string _name, string _icon_name) {
        Object (
            title: _name,
            icon_name: _icon_name
        );

        is_inbox = false;
        is_today = false;
        is_upcoming = false;
        is_project = false;
        is_task = false;
        is_all_tasks = false;
        is_completed = false;

        project_id = 0;
        task_id = 0;
    }

    construct {
        //can_focus = false;
        get_style_context ().add_class ("find-row");

        name_label = new Gtk.Label (null);
        name_label.get_style_context ().add_class ("h3");
        name_label.ellipsize = Pango.EllipsizeMode.END;
        name_label.use_markup = true;

        image = new Gtk.Image ();
        image.margin_top = 1;

        var main_grid = new Gtk.Grid ();
        main_grid.margin = 6;
        main_grid.column_spacing = 6;
        main_grid.add (image);
        main_grid.add (name_label);

        add (main_grid);
    }
}
