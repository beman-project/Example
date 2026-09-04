#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import os
import subprocess
import tempfile
import shutil
import stat

def main():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    repo_root = os.path.realpath(os.path.join(script_dir, ".."))

    with tempfile.TemporaryDirectory() as work_dir:
        prepared_source = os.path.join(work_dir, "prepared_source")
        output_dir = os.path.join(work_dir, "default")

        print("Preparing dirty working tree for Copier...")
        # Rsync like check_copier.sh to capture dirty working tree without .git
        subprocess.run([
            "rsync", "-a",
            "--exclude", ".git",
            "--exclude", "build",
            "--exclude", ".venv",
            f"{repo_root}/", f"{prepared_source}/"
        ], check=True)

        print("Generating template base case...")
        subprocess.run([
            "uvx", "--from", "copier", "copier", "copy",
            "--trust", "--defaults",
            "-d", "generating_exemplar=true",
            prepared_source, output_dir
        ], cwd=prepared_source, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        diff_cmd = [
            "diff", "-u", "-r",
            "--exclude", ".git",
            "--exclude", "build",
            "--exclude", ".venv",
            "--exclude", "template",
            "--exclude", "copier",
            "--exclude", "copier.yml",
            "--exclude", "stamp.sh",
            "--exclude", "images",
            "--exclude", ".copier-answers.yml",
            "--exclude", "copier_test.yml",
            "--exclude", "catch2_exemplar_test.yml",
            "--exclude", "todo_exemplar_test.yml",
            repo_root, output_dir
        ]

        result = subprocess.run(diff_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if not result.stdout.strip():
            print("No differences found. Templates are synchronized.")
            return

        lines = result.stdout.splitlines()
        mismatched_files = []
        for line in lines:
            if line.startswith("--- " + repo_root):
                file_path = line[4:].split("\t")[0].strip()
                rel_path = os.path.relpath(file_path, repo_root)
                mismatched_files.append(rel_path)

        for rel_path in mismatched_files:
            root_file = os.path.join(repo_root, rel_path)

            template_file_jinja = os.path.join(repo_root, "template", rel_path + ".jinja")
            template_file_plain = os.path.join(repo_root, "template", rel_path)

            target_template = None
            if os.path.exists(template_file_jinja):
                target_template = template_file_jinja
            elif os.path.exists(template_file_plain):
                target_template = template_file_plain

            if not target_template:
                print(f"Warning: {rel_path} not found in template/. Skipping.")
                continue

            with open(target_template, 'r') as tf:
                content = tf.read()

            has_jinja = "{{" in content or "{%" in content

            if has_jinja:
                lines = content.split('\n')
                if len(lines) > 2 and "{% raw -%}" in lines[1] and "{% endraw %}" in lines[-2]:
                    print(f"Updating template for {rel_path} (raw block)")
                    with open(root_file, 'r') as rf:
                        root_content = rf.read()

                    new_content = lines[0] + "\n{% raw -%}\n" + root_content + "\n{% endraw %}"
                    if content.endswith("\n"):
                        new_content += "\n"
                    with open(target_template, 'w') as tf:
                        tf.write(new_content)
                else:
                    print(f"Skipping {rel_path} because the template uses Jinja variables.")
            else:
                print(f"Updating static template for {rel_path}")
                shutil.copy2(root_file, target_template)

if __name__ == "__main__":
    main()
