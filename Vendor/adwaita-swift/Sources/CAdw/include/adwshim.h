#pragma once

#include <adwaita.h>
#include <gtk/gtk.h>

void filedialog_on_open_cb (GtkFileDialog *, const char *, uint64_t);
void filedialog_on_save_cb (GtkFileDialog *, const char *, uint64_t);
void alertdialog_on_close_cb (AdwAlertDialog *, const char *, uint64_t);

void gtui_filedialog_save_finish (GObject *, GAsyncResult *, void *);
void gtui_filedialog_save (GtkFileDialog *, gpointer, GtkWindow *);
void gtui_filedialog_open_finish (GObject *, GAsyncResult *, void *);
void gtui_filedialog_open (GtkFileDialog *, gpointer, GtkWindow *);
void gtui_filedialog_open_folder_finish (GObject *, GAsyncResult *, void *);
void gtui_filedialog_open_folder (GtkFileDialog *, gpointer, GtkWindow *);
void gtui_alertdialog_cb (GObject *, GAsyncResult *, void *);
void gtui_alertdialog_choose (AdwAlertDialog *, gpointer, GtkWidget *);
GValue gtui_initialize_boolean (gboolean);
void gtui_cssprovider_set_prefers_color_scheme (GObject *, GtkInterfaceColorScheme);

