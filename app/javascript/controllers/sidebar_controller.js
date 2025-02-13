import {Controller} from "@hotwired/stimulus"

export default class extends Controller {

    static targets = ["wrapper"];

    toggle(e) {
        e.preventDefault();
        $(this.wrapperTarget).toggleClass("toggled");
    }
}
