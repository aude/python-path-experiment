Python import path experiment
=============================

The point of this experiment is to see how Python's import path is behaving.

- Should `python package/script.py` be used?
- _Can_ `python package/script.py` be used?
- Should `python -m package.script` be used?
- What's the right way to do it?

Let's find out.

TL;DR
-----

	$ sh experiment.sh
	+ python cli/run.py
	Traceback (most recent call last):
	  File "cli/run.py", line 1, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils.logging'
	++ pwd
	+ PYTHONPATH=/home/.../python-path-experiment
	+ python cli/run.py
	logging: test message
	+ python -m cli.run
	logging: test message

python package/script.py
------------------------

In this repo, there are two packages:

- `cli`
- `utils`

`cli/run.py` imports a function from `utils/logging.py` and uses it:

	from utils.logging import info

	info("hello world")

Let's try to run it:

	$ python cli/run.py
	Traceback (most recent call last):
	  File "cli/run.py", line 1, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils'

Crap. It doesn't work.

Let's try from it's directory:

	$ cd cli
	$ python run.py
	Traceback (most recent call last):
	  File "run.py", line 1, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils'

Nope. Doesn't work either.

...

Okay, we can try to get to the bottom of why it doesn't work.

In order for `from utils.logging import info` to work,
**the utils package must be findable by Python**.

Let's take a look at Python's import path:

	$ echo 'import sys

	print(sys.path)' > cli/run.py
	$ python cli/run.py
	['/home/.../python-path-experiment/cli', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']

Aha!

The current directory does not seem to be in Python's import path. No wonder it doesn't
work.

Python does seems to add a path though: The parent directory of the script we are
executing.

Let's verify:

	$ mkdir cli/tools
	$ echo 'import sys

	print(sys.path)' > cli/tools/run.py
	$ python cli/tools/run.py
	['/home/.../python-path-experiment/cli/tools', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']

Yep. The script's directory is added to the import path, **not** the current directory.

Let's clean up:

	$ git clean -df
	$ git checkout .

PYTHONPATH
----------

So, how can we add the current directory to the import path?

The official documentation for
[sys.path](https://docs.python.org/3/library/sys.html#sys.path)
has information on how to do that.

One way is to set the environment variable `PYTHONPATH`.

Let's try:

	$ PYTHONPATH=$(pwd) python cli/run.py
	logging: test message

Oh! So this works. Let's see what the import path looks like:

	$ echo 'import sys

	print(sys.path)' > cli/run.py
	$ PYTHONPATH=$(pwd) python cli/run.py
	['/home/.../python-path-experiment/cli', '/home/.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']

Yep, the current directory is there. That's why it works.

Though, that first path there looks a bit awkward.
It doesn't really feel correct that `.../cli` is there for no reason, does it?

Let's clean up:

	$ git clean -df
	$ git checkout .

PYTHONPATH's downfall
---------------------

Actually, what if there is a `utils` package inside `cli`?
Will it override the original one?

	$ PYTHONPATH=$(pwd) python cli/run.py
	logging: test message
	$ mkdir cli/utils
	$ touch cli/utils/__init__.py
	$ echo 'def info(msg):
	    print("muhaha")' > cli/utils/logging.py
	$ PYTHONPATH=$(pwd) python cli/run.py
	muhaha

Yeah, nope. Don't want that.

Using `PYTHONPATH` does not do what we intended.

Time to clean:

	$ git clean -df
	$ git checkout .

python -m
---------

So what _can_ we do? What is best practice for spawning a script inside a package?

Let's [consult](https://stackoverflow.com/a/47030746)
[the](https://stackoverflow.com/a/6466139)
[interwebz](https://stackoverflow.com/a/14132912).

Several resources are pointing to `sys.path` hacks, but are also mentioning `python -m`.
Could it be more correct than directly setting the Python import path?

Guido [says yes](https://mail.python.org/pipermail/python-3000/2007-April/006793.html):

> ... running scripts that happen to be living inside a module's directory, which I've
> always seen as an antipattern. To make me change my mind you'd have to convince me
> that it isn't. - Guido van Rossum

Let's try it:

	$ python -m cli.run
	logging: test message

It works!

Let's check Python's import path this time:

	$ echo 'import sys

	print(sys.path)' > cli/run.py
	$ python cli.run
	['/home/.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']

Kapow! It's correct.

But blah, `python -m cli.run` is annoying to write :/
It doesn't even have reliable tab completion. Meh.

But as far as this experiment goes, it emerges as a correct way to run the script
`cli/run.py`.

Clean up:

	$ git clean -df
	$ git checkout .

Conclusion
----------

| Method                                    | Works well |
| ----------------------------------------- | ---------- |
| `python package/script.py`                | ✖          |
| `PYTHONPATH=... python package/script.py` | ✖          |
| `python -m package.script`                | ✔          |

`python -m` emerged as the solution that worked best. It does have an annoying lack of
tab completion, and that makes it less attractive to use for people who appreciate tab
completion. But that's about user experience, not functionality.

And hey! Python is free software! Go make the tab completion if you want it to happen! :D

If you know something not covered, feel free to make a pull request!

Bonus question
--------------

What happens if we remove `__init__.py` files, to create
[implicit namespace packages](https://www.python.org/dev/peps/pep-0420/)?

	$ rm */__init__.py
	$ sh experiment.sh
	+ python cli/run.py
	Traceback (most recent call last):
	  File "cli/run.py", line 1, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils.logging'
	++ pwd
	+ PYTHONPATH=/home/.../python-path-experiment
	+ python cli/run.py
	logging: test message
	+ python -m cli.run
	logging: test message

So the behavior is the same. Hmm.

Will have to dig more into Python packages without `__init__.py` another day.

More information
----------------

- https://docs.python.org/3/tutorial/modules.html
- https://docs.python.org/3/library/sys.html#sys.path
- https://www.devdungeon.com/content/python-import-syspath-and-pythonpath-tutorial
