HTML comments are hidden, so they can hold notes for the speaker:

<!-- speaker notes: mention the demo here -->

<!--
More speaker notes, over several lines.

Blank lines inside the comment are fine.
-->

Other HTML blocks show their raw source, dimmed:

<div class="note">
  *Markdown* inside stays as it is.
</div>

<details>
<summary>A summary line that is long enough to wrap at sixty columns</summary>
</details>

A comment can also interrupt a paragraph
<!-- speaker notes: without a blank line -->
and the next line starts a new paragraph.

<pre>
blank lines inside pre

do not end it
</pre>

<?php echo 'processing instructions'; ?>

<!DOCTYPE html>

<![CDATA[ character data ]]>

<custom-element attr="x">

Inline tags such as <span>this one</span> stay in their paragraph.
