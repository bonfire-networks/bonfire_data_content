defmodule Bonfire.Pages.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  alias Bonfire.Data.Social.PostContent
  alias Bonfire.Pages.Page
  alias Bonfire.Pages.Section
  alias Ecto.Changeset

  def handle_event("create_page", params, socket) do
    attrs =
      params
      |> Map.merge(e(params, :page, %{}))
      |> debug("page params")
      |> input_to_atoms()

    # |> debug("post attrs")

    # debug(e(socket.assigns, :showing_within, nil), "SHOWING")
    current_user = current_user_required(socket)

    with %{} <- current_user || {:error, "You must be logged in"},
         # fail before uploading
         %{valid?: true} <- Page.changeset(attrs),
         uploaded_media <-
           Bonfire.Social.Posts.LiveHandler.multi_upload(
             current_user,
             params["upload_metadata"],
             socket
           ),
         attrs <- Map.put(attrs, :uploaded_media, uploaded_media),
         opts <-
           [
             current_user: current_user,
             page_attrs: attrs,
             boundary: e(params, "to_boundaries", "mentions")
           ]
           |> debug("use opts for boundary + save field in PostContent"),
         {:ok, published} <- Bonfire.Pages.create(opts) do
      published
      |> repo().maybe_preload([:post_content])
      |> dump("created!")

      # activity = e(published, :activity, nil)

      permalink = path(published)

      debug(permalink, "permalink")

      {
        :noreply,
        socket
        |> assign_flash(
          :info,
          "#{l("Created!")}"
        )
        |> Bonfire.UI.Common.SmartInputLive.reset_input()
        |> patch_to(path(published))
      }
    else
      e ->
        error(error_msg(e))

        {
          :noreply,
          socket
          |> assign_flash(:error, "Could not create 😢 (#{error_msg(e)})")
          # |> patch_to(current_url(socket), fallback: "/error") # so the flash appears
        }
    end
  end

  def handle_event("edit_section", params, socket) do
    attrs =
      params
      |> Map.merge(e(params, :section, %{}))
      |> debug("section params")
      |> input_to_atoms()

    # |> debug("post attrs")

    # debug(e(socket.assigns, :showing_within, nil), "SHOWING")
    current_user = current_user_required(socket)

    with %{} <- current_user || {:error, "You must be logged in"},
         # fail before uploading
         %{valid?: true} <- Section.changeset(attrs),
         uploaded_media <-
           Bonfire.Social.Posts.LiveHandler.multi_upload(
             current_user,
             params["upload_metadata"],
             socket
           ),
         attrs <- Map.put(attrs, :uploaded_media, uploaded_media),
         opts <-
           [
             current_user: current_user,
             section_attrs: attrs,
             boundary: e(params, "to_boundaries", "mentions")
           ]
           |> debug("use opts for boundary + save fields in PostContent"),
         {:ok, published} <- Bonfire.Pages.Sections.upsert(opts) do
      page_id = e(attrs, :reply_to, :thread_id, nil)

      if page_id,
        do:
          Bonfire.Pages.Sections.put_in_page(ulid(published), page_id)
          |> debug("put_in_page")

      published
      |> repo().maybe_preload([:post_content])
      |> dump("created!")

      # activity = e(published, :activity, nil)

      # permalink = path(published)
      # |> debug("permalink")

      {
        :noreply,
        socket
        |> assign_flash(
          :info,
          l("Created!")
        )
        |> Bonfire.UI.Common.SmartInputLive.reset_input()
        |> patch_to(current_url(socket), fallback: path(published))
      }
    else
      e ->
        error(error_msg(e))

        {
          :noreply,
          socket
          |> assign_flash(:error, "Could not create 😢 (#{error_msg(e)})")
          # |> patch_to(current_url(socket), fallback: "/error") # so the flash appears
        }
    end
  end

  def handle_event("add_section", %{"section_id" => section_id} = params, socket) do
    page = e(socket.assigns, :object, nil) || e(params, "page_id", nil)

    Bonfire.Pages.Sections.put_in_page(ulid!(section_id), ulid!(page))
    |> debug("put_in_page")

    {
      :noreply,
      socket
      |> assign_flash(
        :info,
        l("Added!")
      )
      |> patch_to(current_url(socket), fallback: path(page))
    }
  end

  def handle_event("remove_section", %{"section_id" => section_id} = params, socket) do
    page = e(socket.assigns, :object, nil) || e(params, "page_id", nil)

    Bonfire.Pages.Sections.remove_from_page(ulid!(section_id), ulid!(page))
    |> debug("remove_from_page")

    {
      :noreply,
      socket
      |> assign_flash(
        :info,
        l("Removed!")
      )
      |> patch_to(current_url(socket), fallback: path(page))
    }
  end

  # def handle_params(%{"after" => cursor} = attrs, _, %{assigns: %{thread_id: thread_id}} = socket) do
  #   live_more(thread_id, [after: cursor], socket)
  # end

  # def handle_params(%{"after" => cursor, "context" => thread_id} = attrs, _, socket) do
  #   live_more(thread_id, [after: cursor], socket)
  # end

  # def handle_event(
  #       "load_more",
  #       %{"after" => cursor} = attrs,
  #       %{assigns: %{thread_id: thread_id}} = socket
  #     ) do
  #   live_more(thread_id, input_to_atoms(attrs), socket)
  # end
end
