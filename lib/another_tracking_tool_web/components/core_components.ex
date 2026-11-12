defmodule AnotherTrackingToolWeb.CoreComponents do
  use Phoenix.Component
  use Gettext, backend: AnotherTrackingToolWeb.Gettext

  alias AnotherTrackingTool.WatchStatuses
  alias Phoenix.Flash
  alias Phoenix.HTML.Form
  alias Phoenix.HTML.FormField
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.LiveStream

  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary outline ghost)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary",
      "outline" => "btn-outline",
      "ghost" => "btn-ghost",
      nil => "btn-primary"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn rounded-full font-extrabold", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :unit, :string, default: nil
  attr :hero, :boolean, default: false
  slot :foot

  def stat_tile(assigns) do
    assigns =
      assign(assigns, :quiet, if(assigns.hero, do: "text-paper-2/70", else: "text-ink-soft"))

    ~H"""
    <div class={[
      "flex flex-col gap-1 rounded-2xl border p-4",
      if(@hero, do: "border-ink bg-ink text-paper-0", else: "border-line bg-paper-0")
    ]}>
      <span class={["text-[10px] font-extrabold uppercase tracking-widest", @quiet]}>
        {@label}
      </span>
      <span class="flex flex-wrap items-baseline gap-1.5 font-display text-3xl font-bold tabular-nums">
        {@value}
        <span :if={@unit} class={["font-sans text-xs font-bold tracking-wide", @quiet]}>
          {@unit}
        </span>
      </span>
      <span :if={@foot != []} class={["text-xs", @quiet]}>
        {render_slot(@foot)}
      </span>
    </div>
    """
  end

  attr :active, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def filter_chip(assigns) do
    ~H"""
    <button
      type="button"
      aria-pressed={to_string(@active)}
      class={[
        "rounded-full border px-3 py-1 text-xs font-bold",
        if(@active,
          do: "border-ink bg-ink text-paper-0",
          else: "border-line text-ink-soft hover:bg-paper-2 hover:text-ink"
        )
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :class, :any, default: nil
  slot :inner_block, required: true

  def section_label(assigns) do
    ~H"""
    <p class={["text-xs font-extrabold uppercase tracking-widest text-ink-soft", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :status, :atom, required: true, values: WatchStatuses.all()
  attr :label, :string, default: nil
  attr :muted, :boolean, default: false
  attr :class, :any, default: nil

  def status_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-bold",
      pill_class(@muted, @status),
      @class
    ]}>
      <span
        :if={!@muted and @status != :dropped}
        class={["size-1.5 rounded-full", dot_class(@status)]}
      ></span>
      {@label || watch_status_label(@status)}
    </span>
    """
  end

  defp pill_class(true, _status), do: "border-transparent bg-paper-2 text-ink-soft"
  defp pill_class(false, :completed), do: "border-ink bg-ink text-paper-0"
  defp pill_class(false, :watching), do: "border-ink text-ink"
  defp pill_class(false, :planned), do: "border-line text-ink-soft"
  defp pill_class(false, :dropped), do: "border-dashed border-line text-ink-faint"

  defp dot_class(:completed), do: "bg-current"
  defp dot_class(:planned), do: "shadow-[inset_0_0_0_1px_currentColor]"

  defp dot_class(:watching),
    do:
      "bg-[linear-gradient(90deg,currentColor_50%,transparent_50%)] shadow-[inset_0_0_0_1px_currentColor]"

  def watch_status_label(:watching), do: dgettext("catalog", "Watching")
  def watch_status_label(:completed), do: dgettext("catalog", "Completed")
  def watch_status_label(:dropped), do: dgettext("catalog", "Dropped")
  def watch_status_label(:planned), do: dgettext("catalog", "Planned")
  def watch_status_label(:not_interested), do: dgettext("catalog", "Not for me")

  attr :src, :string, default: nil
  attr :alt, :string, default: ""
  attr :framed, :boolean, default: true
  attr :class, :any, default: nil

  def poster(assigns) do
    ~H"""
    <div class={["overflow-hidden", @framed && "rounded-2xl bg-paper-2 p-3", @class]}>
      <div class="relative aspect-[2/3] overflow-hidden rounded-xl">
        <img :if={@src} src={@src} alt={@alt} class="size-full object-cover" />
        <div
          :if={!@src}
          class="size-full bg-gradient-to-b from-line-soft to-line"
        >
        </div>
      </div>
    </div>
    """
  end

  attr :rest, :global, include: ~w(name value placeholder autocomplete)

  def search_input(assigns) do
    ~H"""
    <div class="flex items-center gap-2 rounded-full bg-paper-2 px-5 py-3">
      <.icon name="hero-magnifying-glass" class="size-4 text-ink-soft" />
      <input
        type="search"
        class="w-full bg-transparent text-sm text-ink placeholder:text-ink-soft focus:outline-none"
        {@rest}
      />
    </div>
    """
  end

  attr :initial, :string, required: true
  attr :color, :string, required: true
  attr :class, :any, default: nil

  def avatar(assigns) do
    ~H"""
    <div
      class={[
        "flex size-9 shrink-0 items-center justify-center rounded-full text-xs font-extrabold text-white",
        @class
      ]}
      style={"background: #{@color}"}
    >
      {@initial}
    </div>
    """
  end

  attr :people, :list, required: true, doc: "list of %{initial:, color:}"
  attr :extra, :integer, default: 0

  def avatar_stack(assigns) do
    ~H"""
    <div class="flex">
      <.avatar
        :for={person <- @people}
        initial={person.initial}
        color={person.color}
        class="-ml-2.5 border-2 border-paper first:ml-0"
      />
      <div
        :if={@extra > 0}
        class="-ml-2.5 flex size-9 items-center justify-center rounded-full border-2 border-paper bg-line text-xs font-extrabold text-ink-soft"
      >
        +{@extra}
      </div>
    </div>
    """
  end

  attr :value, :integer, default: 0
  attr :max, :integer, default: 5
  attr :class, :any, default: "text-lg"

  def stars(assigns) do
    ~H"""
    <div class={["tracking-[3px] text-ink", @class]}>
      <span :for={i <- 1..@max} class={if i > @value, do: "text-line"}>★</span>
    </div>
    """
  end

  def tmdb_image(path, size \\ "w342")
  def tmdb_image(nil, _size), do: nil
  def tmdb_image(path, size), do: "https://image.tmdb.org/t/p/#{size}#{path}"

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %FormField{} = field} = assigns) do
    errors = if used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(AnotherTrackingToolWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AnotherTrackingToolWeb.Gettext, "errors", msg, opts)
    end
  end

  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
