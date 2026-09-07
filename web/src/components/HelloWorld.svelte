<script lang="ts">
  import { sellData, visibility } from '../store/stores';
  import { fetchNui } from '../utils/fetchNui';

  const handleConfirm = () => {
    fetchNui('accept');
    visibility.set(false);
  };

  const handleDeny = () => {
    fetchNui('decline');
    visibility.set(false);
  };
</script>

<div class="container">
  <img class="item-image" src={$sellData.img} alt={$sellData.itemLabel} />

  <div class="item-label">{$sellData.itemLabel}</div>

  <div class="price-row">
    <div class="price-block">
      <span class="price-label">Price</span>
      <span class="price-value">${$sellData.singlePrice.toFixed(2)}</span>
    </div>
    <div class="price-block">
      <span class="price-label">Qty</span>
      <span class="price-value">{$sellData.amount}</span>
    </div>
    <div class="price-block">
      <span class="price-label">Total</span>
      <span class="price-value">${$sellData.total.toFixed(2)}</span>
    </div>
  </div>

  <div class="btn-wrapper">
    <button class="deny" on:click={handleDeny}>Deny</button>
    <button class="confirm" on:click={handleConfirm}>Confirm</button>
  </div>
</div>

<style>
  .container {
    position: absolute;
    top: 50%;
    right: 2vw;
    transform: translateY(-50%);
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 1.2vh;
    border-radius: 8px;
    width: 16vw;
    padding: 2vh 1.2vw;
    font-size: 1.4vh;
    color: white;
    background-color: rgba(20, 20, 20, 0.9);
    user-select: none;
  }

  .item-image {
    width: 8vw;
    height: 8vw;
    object-fit: contain;
    border-radius: 6px;
    background-color: rgba(255, 255, 255, 0.05);
    padding: 0.6vh;
  }

  .item-label {
    font-size: 1.8vh;
    font-weight: 600;
    text-align: center;
  }

  .price-row {
    display: flex;
    justify-content: space-between;
    width: 100%;
  }

  .price-block {
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 1;
  }

  .price-label {
    font-size: 1.1vh;
    color: rgba(255, 255, 255, 0.6);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .price-value {
    font-size: 1.5vh;
    font-weight: 600;
    margin-top: 0.3vh;
  }

  .btn-wrapper {
    display: flex;
    justify-content: space-evenly;
    align-items: center;
    width: 100%;
    gap: 0.8vw;
  }

  button {
    flex: 1;
    padding: 0.8vh;
    font-family: inherit;
    font-size: 1.3vh;
    font-weight: 600;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    transition: background-color 0.15s ease;
  }

  .confirm {
    background-color: #2ecc71;
    color: white;
  }

  .confirm:hover {
    background-color: #27ae60;
  }

  .deny {
    background-color: #e74c3c;
    color: white;
  }

  .deny:hover {
    background-color: #c0392b;
  }
</style>
