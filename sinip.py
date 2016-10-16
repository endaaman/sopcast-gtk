

vala sopcast.vala --pkg gtk+-3.0 --pkg libsoup-2.4 --thread

import signal
signal.signal(signal.SIGINT, signal.SIG_DFL)



import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk


class GridWindow(Gtk.Window):

    def __init__(self):
        Gtk.Window.__init__(self, title="Grid Example")

        grid = Gtk.Grid()
        self.add(grid)

        button1 = Gtk.Button(label="Button 1")
        button2 = Gtk.Button(label="Button 2")
        button3 = Gtk.Button(label="Button 3")
        button4 = Gtk.Button(label="Button 4")
        button5 = Gtk.Button(label="Button 5")
        button6 = Gtk.Button(label="Button 6")

        grid.add(button1)
        grid.attach(button2, 1, 0, 2, 1)
        grid.attach_next_to(button3, button1, Gtk.PositionType.BOTTOM, 1, 2)
        grid.attach_next_to(button4, button3, Gtk.PositionType.RIGHT, 2, 1)
        grid.attach(button5, 1, 2, 1, 1)
        grid.attach_next_to(button6, button5, Gtk.PositionType.RIGHT, 1, 1)



if __name__ == '__main__':
    import signal
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    win = GridWindow()
    win.connect("delete-event", Gtk.main_quit)
    win.show_all()
    Gtk.main()








int main(string[] args) {
  Gtk.init(ref args);

  var window = new Window();
  window.title = "First GTK+ Program";
  window.border_width = 10;
  window.window_position = WindowPosition.CENTER;
  window.set_default_size(350, 70);
  window.destroy.connect(Gtk.main_quit);

  if (args.length < 2) {
    print ("not enough arguments");
    return 1;
  }
  string sopurl = args[1];
  uint id_childwatch;

  GLib.Pid child_pid;
  try {
    string[] child_argv = {"ext", sopurl};
    var suc = GLib.Process.spawn_async_with_pipes(
      null,
      child_argv,
      null,
      GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
      null,
      out child_pid,
      null,
      null,
      null);
    if (suc) {
      id_childwatch = GLib.ChildWatch.add(child_pid, (pid, status) => {
        print("child exited, raw status: %d", status);
        if (GLib.Process.if_exited(status)) {
          print(" exit status: %d", GLib.Process.exit_status(status));
        }
        print("\n");
        GLib.Process.close_pid(pid);
        GLib.Source.remove(id_childwatch);
      });
    }
  } catch (GLib.SpawnError e) {
    GLib.warning ("spawn failed: %s", e.message);
    return 1;
  }


  var button = new Button.with_label(@"url: $sopurl");
  button.clicked.connect(() => {
    button.label = "Thank you";
  });

  window.add(button);
  window.show_all();

  Gtk.main();
  return 0;
}

