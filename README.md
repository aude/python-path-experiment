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
	sys.path: ['.../python-path-experiment/cli', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	Traceback (most recent call last):
	  File "cli/run.py", line 4, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils'
	++ pwd
	+ PYTHONPATH=.../python-path-experiment
	+ python cli/run.py
	sys.path: ['.../python-path-experiment/cli', '.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message
	+ python -m cli.run
	sys.path: ['.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message

python package/script.py
------------------------

In this repo, there are two packages:

- `cli`
- `utils`

> Note that there are two _packages_, not two _modules_. That makes this a **monorepo**.

`cli/run.py` first prints `sys.path`, then imports a function from `utils/logging.py`
and uses it:

```python
import sys
print("sys.path:", sys.path)

from utils.logging import info
info("hello world")
```

Let's try to run it:

	$ python cli/run.py
	sys.path: ['.../python-path-experiment/cli', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	Traceback (most recent call last):
	  File "cli/run.py", line 4, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils'

Crap. It doesn't work.

Let's try from it's directory:

	$ cd cli
	$ python run.py
	sys.path: ['.../python-path-experiment/cli', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	Traceback (most recent call last):
	  File "cli/run.py", line 4, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils'

Nope. Doesn't work either.

...

Okay, we can try to get to the bottom of why it doesn't work.

In order for `from utils.logging import info` to work,
**the `utils` package must be findable by Python**.

Let's take a look at Python's import path:

	$ python cli/run.py
	sys.path: ['.../python-path-experiment/cli', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	...

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
	['.../python-path-experiment/cli/tools', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']

Yep! The script's directory is added to the import path, **not** the current directory.

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
	sys.path: ['.../python-path-experiment/cli', '.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message

Oh! So this works.

Looking at the import path, we can see that the current directory is there.
That's why it works.

Though, that first path there looks a bit awkward. Is it correct that `.../cli` is
there?

PYTHONPATH's side effect
------------------------

Actually, what if there is a `utils` package inside `cli`?
Will it override the original one?

	$ PYTHONPATH=$(pwd) python cli/run.py
	sys.path: ['.../python-path-experiment/cli', '.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message
	$ mkdir cli/utils
	$ touch cli/utils/__init__.py
	$ echo 'def info(msg):
	    print("override message")' > cli/utils/logging.py
	$ PYTHONPATH=$(pwd) python cli/run.py
	override message

Yes, it does override! Do we want this?

The answer depends on what you are building:

If you are building a **monorepo**, the answer is **yes**.
The reason is that you're bundling multiple _packages_, isolated code bases, in one
repository. In order for one package to have any clue where to look for other packages,
you have to make them all available in `sys.path`. Setting `PYTHONPATH` is one way to
do that.

If you are building a **monolith**, not a monorepo, the answer is **no**.
If you're building a monolith, keep everything in one package. Then you don't need
to look in `sys.path`, because you can use [relative imports](https://docs.python.org/3/reference/import.html#package-relative-imports).

If you are building a **multirepo**, you don't need any of this.
You can use `pip install` or git submodules or something, you probably know already.

Time to clean:

	$ git clean -df
	$ git checkout .

python -m
---------

So, this whole `PYTHONPATH` feels a bit complicated. Can we make it without it?
What is best practice for running a script inside a package?

Let's [consult](https://stackoverflow.com/a/47030746)
[the](https://stackoverflow.com/a/6466139)
[interwebz](https://stackoverflow.com/a/14132912).

Several resources are pointing to `sys.path` hacks, but are also mentioning `python -m`.
Could it be more correct than directly setting the Python import path?

Let's try it:

	$ python -m cli.run
	sys.path: ['.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message

It works!

The import path, though, might not be correct.

For a **monorepo**, it is **not correct**. Every package's directory should be in
`sys.path`, so `.../cli` should have been there in this case.

For a **multirepo**, it is **not correct** either. The package's directory should be in
`sys.path`, so `.../cli` should have been there.

`python -m` seems most suitable to running scripts from installed packages. This is
probably the reason we are seeing commands like these recommended:

- `python -m venv .venv`
- `python -m flask run`
- `python -m unittest discover`

It could be because it can run a script from `sys.path` without adding the script's
directory to `sys.path`.

Guido says
----------

It's probably worth it to keep in mind Guido's
[opinion](https://mail.python.org/pipermail/python-3000/2007-April/006793.html) on
what we are trying to here:

> ... running scripts that happen to be living inside a module's directory, which I've
> always seen as an antipattern. To make me change my mind you'd have to convince me
> that it isn't. - Guido van Rossum

Installing packages
-------------------

In the end, the most correct way to distribute packages is to install them, probably
inside a virtual environment.

This experiment does not look into that, because it focuses on easy out-of-the-box
solutions.

If you want to look into it, here is some information:
- https://stackoverflow.com/a/50193944
- https://packaging.python.org/tutorials/packaging-projects/
- Example: https://github.com/FrodeHus/instapull

Conclusion
----------

For **monorepo**:

| Method                                    | Works well |
| ----------------------------------------- | ---------- |
| `python package/script.py`                | ✖          |
| `PYTHONPATH=... python package/script.py` | ✔          |
| `python -m package.script`                | ✖          |
| Installing packages                       | ✔          |

For **multirepo**:

| Method                                    | Works well |
| ----------------------------------------- | ---------- |
| `python package/script.py`                | ✔          |
| `PYTHONPATH=... python package/script.py` | ✔          |
| `python -m package.script`                | ✖          |
| Installing packages                       | ✔          |

`PYTHONPATH` emerged as the easy solution that worked best for monorepos, while
`python package/script.py` was the easy solution that worked best for monoliths and
multirepos.

Installing packages worked best, but was less easy.

If you know something not covered here, feel free to make a pull request!

Bonus question
--------------

What happens if we remove `__init__.py` files, to create
[implicit namespace packages](https://www.python.org/dev/peps/pep-0420/)?

	$ rm */__init__.py
	$ sh experiment.sh
	+ python cli/run.py
	sys.path: ['.../python-path-experiment/cli', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	Traceback (most recent call last):
	  File "cli/run.py", line 4, in <module>
	    from utils.logging import info
	ModuleNotFoundError: No module named 'utils'
	++ pwd
	+ PYTHONPATH=.../python-path-experiment
	+ python cli/run.py
	sys.path: ['.../python-path-experiment/cli', '.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message
	+ python -m cli.run
	sys.path: ['.../python-path-experiment', '/usr/lib/python38.zip', '/usr/lib/python3.8', '/usr/lib/python3.8/lib-dynload', '/usr/lib/python3.8/site-packages']
	logging: test message

So the behavior is the same. Hmm.

Will have to dig more into Python packages without `__init__.py` another day.

Clean:

	$ git clean -df
	$ git checkout .

More information
----------------

- https://docs.python.org/3/tutorial/modules.html
- https://docs.python.org/3/library/sys.html#sys.path
- https://www.devdungeon.com/content/python-import-syspath-and-pythonpath-tutorial
