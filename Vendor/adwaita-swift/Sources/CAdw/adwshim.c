#include "adwshim.h"

#include <adwaita.h>
#include <gtk/gtk.h>

void gtui_filedialog_save_finish (GObject * dialog, GAsyncResult * result, void * data)
{
  GFile      *file = gtk_file_dialog_save_finish ((GtkFileDialog *)dialog, result, NULL);
  const char *path = g_file_get_path (file);
  filedialog_on_save_cb ((GtkFileDialog *)dialog, path, (uint64_t)data);
  g_object_unref (file);
}

void gtui_filedialog_save (GtkFileDialog * dialog, gpointer data, GtkWindow * window)
{
  gtk_file_dialog_save (dialog, window, NULL, gtui_filedialog_save_finish, (void *)data);
}

void gtui_filedialog_open_finish (GObject * dialog, GAsyncResult * result, void * data)
{
  GFile      *file = gtk_file_dialog_open_finish ((GtkFileDialog *)dialog, result, NULL);
  if (file != NULL) {
    const char *path = g_file_peek_path (file);
    g_object_unref (file);
    filedialog_on_open_cb ((GtkFileDialog *)dialog, path, (uint64_t)data);
  } else {
    filedialog_on_open_cb ((GtkFileDialog *)dialog, NULL, (uint64_t)data);
  }
}

void gtui_filedialog_open (GtkFileDialog * dialog, gpointer data, GtkWindow * window)
{
  gtk_file_dialog_open (dialog, window, NULL, gtui_filedialog_open_finish, (void *)data);
}

void gtui_filedialog_open_folder_finish (GObject * dialog, GAsyncResult * result, void * data)
{
  GFile      *file = gtk_file_dialog_select_folder_finish ((GtkFileDialog *)dialog, result, NULL);
  if (file != NULL) {
    const char *path = g_file_peek_path (file);
    g_object_unref (file);
    filedialog_on_open_cb ((GtkFileDialog *)dialog, path, (uint64_t)data);
  } else {
    filedialog_on_open_cb ((GtkFileDialog *)dialog, NULL, (uint64_t)data);
  }
}

void gtui_filedialog_open_folder (GtkFileDialog * dialog, gpointer data, GtkWindow * window)
{
  gtk_file_dialog_select_folder (dialog, window, NULL, gtui_filedialog_open_folder_finish, (void *)data);
}

void gtui_alertdialog_cb (GObject * dialog, GAsyncResult * result, void * data)
{
  const char *response = adw_alert_dialog_choose_finish ((AdwAlertDialog *)dialog, result);
  alertdialog_on_close_cb ((AdwAlertDialog *)dialog, response, (uint64_t)data);
}

void gtui_alertdialog_choose (AdwAlertDialog * dialog, gpointer data, GtkWidget * parent)
{
  adw_alert_dialog_choose (dialog, parent, NULL, gtui_alertdialog_cb, data);
}

GValue gtui_initialize_boolean (gboolean boolean)
{
  GValue val = G_VALUE_INIT;
  g_value_init(&val, G_TYPE_BOOLEAN);
  g_value_set_boolean(&val, boolean);
  return val;
}

void gtui_cssprovider_set_prefers_color_scheme (GObject * provider, GtkInterfaceColorScheme scheme)
{
  GValue val = G_VALUE_INIT;
  g_value_init(&val, G_TYPE_ENUM);
  g_value_set_enum(&val, scheme);
  g_object_set_property(provider, "prefers-color-scheme", &val);
  g_value_unset(&val);
}

