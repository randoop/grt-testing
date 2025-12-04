#!/usr/bin/env python3

"""Obtains the upstream sources and leaves them in `subject-programs/src-upstream`."""

import pathlib
import subprocess
import tarfile
import zipfile
from pathlib import Path
from urllib.request import urlretrieve

import yaml
from yaml.loader import SafeLoader

# open yaml file in read

script_directory = pathlib.Path(__file__).parent.resolve()

with pathlib.Path(script_directory / "build-info.yaml").open() as f:
    yaml_data = list(yaml.load_all(f, Loader=SafeLoader))

src_upstream_dir = script_directory / "src-upstream"
# if os.path.exists(src_upstream_dir):
#     src_upstream_old_dir = script_directory / "src-upstream-OLD"
#     shutil.rmtree(src_upstream_old_dir, ignore_errors=True)
#     os.rename(src_upstream_dir, src_upstream_old_dir)
src_upstream_dir.mkdir(exist_ok=True)

for project in yaml_data:
    source = project["source"]
    proj_dir = project["dir"]
    project_dir = src_upstream_dir / proj_dir
    if pathlib.Path(project_dir).is_dir():
        print("Skipping", proj_dir, "because it exists.")
        continue
    print("About to get", source)
    if source.startswith("http"):
        basename = Path.name(source)
        archive_path = src_upstream_dir / basename
        dest_dir = src_upstream_dir
        key = "extraction-dir"
        if key in project:
            dest_dir = src_upstream_dir / project[key]
        urlretrieve(source, archive_path)
        if source.endswith((".zip", ".jar")):
            with zipfile.ZipFile(archive_path, "r") as zf:
                zf.extractall(dest_dir)
        elif source.endswith(".tar.bz2"):
            with tarfile.open(archive_path, "r:bz2") as tar:
                tar.extractall(path=dest_dir)
        elif source.endswith(".tar.gz"):
            with tarfile.open(archive_path, "r:gz") as tar:
                tar.extractall(path=dest_dir)
        else:
            raise Exception("What type of archive file?", source)
    else:
        command = source.split()
        print("command = ", command)
        completed_process = subprocess.run(command, cwd=src_upstream_dir)
        if completed_process.returncode != 0:
            print("stdout", completed_process.stdout)
            print("stderr", completed_process.stderr)
            raise Exception("command failed: ", command)
    key = "post-extract-command"
    if key in project:
        commands = project[key].split(" && ")
        for command_unsplit in commands:
            command = command_unsplit.split()
            print("dir =", src_upstream_dir)
            print("command =", command)
            completed_process = subprocess.run(command, cwd=src_upstream_dir)
            if completed_process.returncode != 0:
                print("stdout", completed_process.stdout)
                print("stderr", completed_process.stderr)
                raise Exception("command failed: ", command)
    if source.startswith("http"):
        pathlib.Path(archive_path).rename(src_upstream_dir / proj_dir / basename)
